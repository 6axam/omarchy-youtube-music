#!/usr/bin/env python3
"""Local-only CDP bridge. Never logs browser messages or authentication data."""
import asyncio
import json
import math
import os
from pathlib import Path
import signal
import time
from urllib.parse import urlsplit

import aiohttp

HERE = Path(__file__).resolve().parent
PAGE = (HERE / 'page.js').read_text()
SOCKET = Path(os.environ.get('XDG_RUNTIME_DIR') or f'/run/user/{os.getuid()}') / 'omarchy-youtube-music.sock'
CACHE = Path(os.environ.get('XDG_CACHE_HOME') or Path.home() / '.cache') / 'omarchy/youtube-music.json'
ENDPOINT = 'http://127.0.0.1:9222'


def unavailable():
    return dict(available=False, source='youtube-music', sessionId='', title='', artist='', artUrl='', playing=False, position=0, duration=0, canNext=False, canPrevious=False, canSeek=False, album='', queueTitle='', queueId='', currentIndex=-1, shuffle=False, repeat='off', canShuffle=False, canRepeat=False, queue=[], sources=[])


def is_music(target):
    try:
        u = urlsplit(target.get('url', ''))
        return target.get('type') in ('page', 'webview', 'iframe', 'other') and u.scheme == 'https' and u.hostname == 'music.youtube.com' and u.port in (None, 443) and bool(target.get('webSocketDebuggerUrl'))
    except ValueError:
        return False


class Bridge:
    def __init__(self, endpoint=ENDPOINT, cache=CACHE):
        self.endpoint, self.cache = endpoint, Path(cache)
        self.state = unavailable()
        self.target = None
        self.last_write = 0.0
        self.last_saved = None
        self.lock = asyncio.Lock()
        self.http = None
        self.found = {}
        # Reuse the last bound CDP target across daemon restarts when it still
        # exists. CDP target IDs change when the browser recreates a page.
        try:
            saved = json.loads(self.cache.read_text(encoding='utf-8'))
            self.pinned_id = saved.get('pinnedSessionId', saved.get('sessionId', '')) if isinstance(saved, dict) else ''
        except (OSError, ValueError):
            self.pinned_id = '' 

    async def evaluate(self, target, request):
        expression = PAGE.replace('__REQUEST__', json.dumps(request, ensure_ascii=True, allow_nan=False))
        async with self.http.ws_connect(target['webSocketDebuggerUrl'], timeout=aiohttp.ClientWSTimeout(ws_close=2), max_msg_size=4*1024*1024) as ws:
            await ws.send_json({'id': 1, 'method': 'Runtime.evaluate', 'params': {'expression': expression, 'returnByValue': True, 'awaitPromise': True, 'userGesture': request.get('command') != 'state'}})
            while True:
                msg = await asyncio.wait_for(ws.receive(), timeout=3)
                if msg.type != aiohttp.WSMsgType.TEXT:
                    raise RuntimeError('CDP connection closed')
                response = json.loads(msg.data)
                if response.get('id') != 1:
                    continue
                result = response.get('result', {})
                if response.get('error') or result.get('exceptionDetails'):
                    raise RuntimeError('Page rejected command')
                return result.get('result', {}).get('value')

    def snapshot(self, target, state, found):
        sources = [dict(sessionId=str(t['id']), title=s.get('title', ''),
                        artist=s.get('artist', ''), playing=bool(s.get('playing')),
                        visible=bool(s.get('visible')), selected=str(t['id']) == str(target['id'])) for t, s in found]
        return {**unavailable(), **{k: state[k] for k in unavailable() if k in state},
                'sessionId':str(target['id']), 'sources':sources}

    async def refresh(self):
        # Serialize discovery, observation and commands: an older observation can
        # never overwrite a command or explicit source selection.
        async with self.lock:
            try:
                async with self.http.get(self.endpoint + '/json/list', timeout=aiohttp.ClientTimeout(total=3)) as response:
                    response.raise_for_status()
                    targets = [t for t in await response.json(content_type=None) if is_music(t)]
                async def inspect(t):
                    try:
                        s = await self.evaluate(t, {'command':'state'})
                        return (t, s) if isinstance(s, dict) and s.get('available') else None
                    except Exception:
                        return None
                found = [x for x in await asyncio.gather(*(inspect(t) for t in targets)) if x]
                self.found = {str(t['id']):(t, s) for t, s in found}
                current = str((self.target or {}).get('id', '') or self.pinned_id)
                target_ids = {str(t['id']) for t in targets}
                if current and current in target_ids and current not in self.found:
                    # The pinned page still exists but cannot be read right now.
                    # Keep it authoritative until it actually disappears.
                    self.target = None
                    pinned = next(t for t in targets if str(t['id']) == current)
                    self.state = self.snapshot(pinned, unavailable(), found)
                    self.state['sources'].append(dict(sessionId=current, title='', artist='',
                                                      playing=False, visible=False, selected=True,
                                                      available=False))
                    self.save(force=bool(self.last_saved and self.last_saved.get('available')))
                    return
                if found:
                    # A pinned source remains authoritative even when paused.
                    selected = self.found.get(current) or max(found, key=lambda x:
                        (bool(x[1].get('playing')), bool(x[1].get('visible'))))
                    self.target, state = selected
                    self.pinned_id = str(self.target['id'])
                    self.state = self.snapshot(self.target, state, found)
                else:
                    self.target, self.state = None, unavailable()
                self.save()
            except (aiohttp.ClientError, asyncio.TimeoutError, ValueError, OSError):
                self.found = {}
                self.target, self.state = None, unavailable()
                self.save()

    def save(self, force=False):
        now = time.monotonic()
        if not force and (now - self.last_write < 1 or (self.state == self.last_saved and now - self.last_write < 5)):
            return
        self.cache.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        payload = {**self.state, 'pinnedSessionId':self.pinned_id, 'updatedAt':int(time.time() * 1000)}
        tmp = self.cache.with_name(f'.{self.cache.name}.{os.getpid()}.tmp')
        try:
            with open(tmp, 'w', encoding='utf-8') as f:
                os.chmod(tmp, 0o600)
                json.dump(payload, f, ensure_ascii=False, allow_nan=False)
            os.replace(tmp, self.cache)
        finally:
            tmp.unlink(missing_ok=True)
        self.last_saved = json.loads(json.dumps(self.state))
        self.last_write = now

    async def command(self, req):
        if not isinstance(req, dict):
            raise ValueError('Expected JSON object')
        cmd = req.get('command')
        if cmd == 'state':
            return {'ok':True, 'state':self.state}
        if cmd not in ('playPause','play','pause','next','previous','select','seek','shuffle','repeat','bind'):
            raise ValueError('Unknown command')
        async with self.lock:
            if cmd == 'bind':
                selected = self.found.get(req.get('sessionId'))
                if not selected:
                    raise ValueError('Unknown sessionId')
                self.target, state = selected
                self.pinned_id = str(self.target['id'])
                self.state = self.snapshot(self.target, state, list(self.found.values()))
                self.save(force=True)
                return {'ok':True, 'state':self.state}
            if not self.target or not self.state['available']:
                raise ValueError('Music session unavailable')
            if req.get('sessionId') != self.state['sessionId']:
                raise ValueError('Stale or missing sessionId')
            action = {'command':cmd}
            if cmd == 'select':
                queue = self.state['queue']
                index, ident = req.get('index'), req.get('id')
                if index is None and isinstance(ident, str):
                    matches = [i for i, item in enumerate(queue) if item.get('id') == ident]
                    if len(matches) != 1:
                        raise ValueError('Invalid queue id')
                    index = matches[0]
                if isinstance(index, bool) or not isinstance(index, int) or not 0 <= index < len(queue):
                    raise ValueError('Invalid queue index')
                item = queue[index]
                if ident is not None and ident != item.get('id'):
                    raise ValueError('Queue id does not match index')
                action.update(index=index, id=item['id'])
            if cmd == 'seek':
                pos = req.get('position')
                if isinstance(pos, bool) or not isinstance(pos, (int,float)) or not math.isfinite(pos) or pos < 0 or pos > self.state['duration'] or not self.state['canSeek']:
                    raise ValueError('Invalid seek position')
                action['position'] = pos
            await self.evaluate(self.target, action)
            # Invalidate cached discoveries after a mutation; a bind must await
            # fresh observations and cannot restore pre-command metadata.
            self.found = {}
        return {'ok':True}

    async def handle(self, reader, writer):
        try:
            line = await asyncio.wait_for(reader.readline(), timeout=5)
            if len(line) > 65536:
                raise ValueError('Request too large')
            result = await self.command(json.loads(line))
        except (ValueError, TypeError, KeyError, json.JSONDecodeError, asyncio.TimeoutError, aiohttp.ClientError, RuntimeError, OSError) as exc:
            result = {'ok':False, 'error':str(exc) if isinstance(exc, ValueError) else 'Request failed'}
        writer.write((json.dumps(result, ensure_ascii=False, allow_nan=False) + '\n').encode())
        try:
            await writer.drain()
        finally:
            writer.close()
            await writer.wait_closed()

    async def poll(self):
        while True:
            await self.refresh()
            await asyncio.sleep(0.5)


async def main():
    SOCKET.parent.mkdir(parents=True, exist_ok=True)
    # Refuse to unlink anything except a stale socket owned by this user.
    if SOCKET.exists():
        import stat
        st = SOCKET.lstat()
        if not stat.S_ISSOCK(st.st_mode) or st.st_uid != os.getuid():
            raise RuntimeError('Socket path is not an owned socket')
        try:
            r, w = await asyncio.open_unix_connection(str(SOCKET))
            w.close(); await w.wait_closed()
            raise RuntimeError('Bridge is already running')
        except (ConnectionRefusedError, FileNotFoundError):
            SOCKET.unlink(missing_ok=True)
    bridge = Bridge()
    async with aiohttp.ClientSession() as bridge.http:
        server = await asyncio.start_unix_server(bridge.handle, str(SOCKET), limit=65537)
        os.chmod(SOCKET, 0o600)
        stop = asyncio.Event()
        loop = asyncio.get_running_loop()
        for sig in (signal.SIGINT, signal.SIGTERM):
            loop.add_signal_handler(sig, stop.set)
        task = asyncio.create_task(bridge.poll())
        try:
            await stop.wait()
        finally:
            task.cancel()
            await asyncio.gather(task, return_exceptions=True)
            bridge.target, bridge.state = None, unavailable()
            bridge.save(force=True)
            server.close(); await server.wait_closed()
            SOCKET.unlink(missing_ok=True)

if __name__ == '__main__':
    asyncio.run(main())
