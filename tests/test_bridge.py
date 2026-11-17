import asyncio
import json
import tempfile
import unittest
from pathlib import Path
from aiohttp import web, ClientSession
from bridge import Bridge, is_music

class BridgeTest(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.events = []
        self.items = [dict(id='0:abc', title='Song', artist='Artist', artUrl='', current=True, index=0)]
        app = web.Application()
        app.router.add_get('/json/list', self.list_targets)
        app.router.add_get('/devtools/page/{target}', self.websocket)
        self.runner = web.AppRunner(app); await self.runner.setup()
        self.site = web.TCPSite(self.runner, '127.0.0.1', 0); await self.site.start()
        self.port = self.site._server.sockets[0].getsockname()[1]
        self.bridge = Bridge(f'http://127.0.0.1:{self.port}', Path(self.tmp.name)/'cache.json')
        self.bridge.http = ClientSession()

    async def asyncTearDown(self):
        await self.bridge.http.close(); await self.runner.cleanup(); self.tmp.cleanup()

    async def list_targets(self, request):
        return web.json_response([{'id':x,'type':'page','url':u,'webSocketDebuggerUrl':f'ws://127.0.0.1:{self.port}/devtools/page/{x}'} for x,u in [('paused','https://music.youtube.com/'),('playing','https://music.youtube.com/watch?v=x'),('other','https://music.youtube.com.evil.test/')]])

    async def websocket(self, request):
        ws = web.WebSocketResponse(); await ws.prepare(request)
        async for msg in ws:
            data = json.loads(msg.data); expression = data['params']['expression']
            self.events.append((request.match_info['target'], expression))
            state = {'available':True,'playing':request.match_info['target']=='playing','queue':self.items,'duration':120,'canSeek':True,'title':'Song'}
            await ws.send_json({'id':data['id'],'result':{'result':{'value':state}}})
        return ws

    async def test_discovery_selection_and_commands(self):
        await self.bridge.refresh()
        self.assertEqual(self.bridge.state['sessionId'], 'playing')
        self.assertTrue(self.bridge.cache.exists())
        self.assertFalse(any(x[0]=='other' for x in self.events))
        with self.assertRaisesRegex(ValueError, 'sessionId'):
            await self.bridge.command({'command':'next','sessionId':'paused'})
        with self.assertRaisesRegex(ValueError, 'index'):
            await self.bridge.command({'command':'select','sessionId':'playing','index':8})
        with self.assertRaisesRegex(ValueError, 'position'):
            await self.bridge.command({'command':'seek','sessionId':'playing','position':float('nan')})
        result = await self.bridge.command({'command':'select','sessionId':'playing','id':'0:abc'})
        self.assertTrue(result['ok'])
        self.assertIn('"index": 0', self.events[-1][1])
        self.assertIn('"id": "0:abc"', self.events[-1][1])

    async def test_binding_stays_pinned_and_routes_actions(self):
        await self.bridge.refresh()
        self.assertEqual({s['sessionId'] for s in self.bridge.state['sources']}, {'paused', 'playing'})
        await self.bridge.command({'command':'bind', 'sessionId':'paused'})
        await self.bridge.refresh()
        self.assertEqual(self.bridge.state['sessionId'], 'paused')
        await self.bridge.command({'command':'shuffle', 'sessionId':'paused'})
        self.assertEqual(self.events[-1][0], 'paused')
        with self.assertRaisesRegex(ValueError, 'sessionId'):
            await self.bridge.command({'command':'repeat', 'sessionId':'playing'})

    async def test_binding_survives_bridge_restart(self):
        await self.bridge.refresh()
        await self.bridge.command({'command':'bind', 'sessionId':'paused'})
        restarted = Bridge(self.bridge.endpoint, self.bridge.cache)
        restarted.http = self.bridge.http
        await restarted.refresh()
        self.assertEqual(restarted.state['sessionId'], 'paused')
        self.assertEqual([x['sessionId'] for x in restarted.state['sources'] if x['selected']], ['paused'])

    async def test_failed_pinned_read_never_switches_to_playing_page(self):
        await self.bridge.refresh()
        await self.bridge.command({'command':'bind', 'sessionId':'paused'})
        original = self.bridge.evaluate
        async def transient_failure(target, request):
            if target['id'] == 'paused' and request['command'] == 'state':
                raise RuntimeError('Transient failure')
            return await original(target, request)
        self.bridge.evaluate = transient_failure
        await self.bridge.refresh()
        self.assertFalse(self.bridge.state['available'])
        self.assertEqual(self.bridge.state['sessionId'], 'paused')
        self.assertEqual(self.bridge.pinned_id, 'paused')
        self.assertEqual({s['sessionId'] for s in self.bridge.state['sources']}, {'paused', 'playing'})
        with self.assertRaisesRegex(ValueError, 'unavailable'):
            await self.bridge.command({'command':'next', 'sessionId':'paused'})
        self.assertFalse(json.loads(self.bridge.cache.read_text())['available'])
        self.bridge.evaluate = original
        await self.bridge.refresh()
        self.assertEqual(self.bridge.state['sessionId'], 'paused')
        self.assertTrue(self.bridge.state['available'])

    async def test_refresh_and_command_do_not_commit_out_of_order(self):
        await self.bridge.refresh()
        original = self.bridge.evaluate
        entered, release = asyncio.Event(), asyncio.Event()
        async def delayed(target, request):
            if request['command'] == 'state' and target['id'] == 'playing':
                entered.set()
                await release.wait()
            return await original(target, request)
        self.bridge.evaluate = delayed
        refresh = asyncio.create_task(self.bridge.refresh())
        await entered.wait()
        bind = asyncio.create_task(self.bridge.command({'command':'bind', 'sessionId':'paused'}))
        await asyncio.sleep(0)
        self.assertFalse(bind.done())
        release.set()
        await asyncio.gather(refresh, bind)
        self.assertEqual(self.bridge.state['sessionId'], 'paused')

    async def test_cache_throttle_and_clear(self):
        await self.bridge.refresh()
        first = self.bridge.cache.read_text()
        self.bridge.state['title'] = 'changed'; self.bridge.save()
        self.assertEqual(first, self.bridge.cache.read_text())
        self.bridge.last_write -= 2; self.bridge.save()
        self.assertEqual(json.loads(self.bridge.cache.read_text())['title'], 'changed')
        self.bridge.endpoint = 'http://127.0.0.1:1'
        self.bridge.last_write -= 2; await self.bridge.refresh()
        self.assertFalse(self.bridge.state['available'])
        self.assertFalse(json.loads(self.bridge.cache.read_text())['available'])

    async def test_heartbeat_and_forced_shutdown_snapshot(self):
        await self.bridge.refresh()
        self.bridge.last_write -= 6
        before = self.bridge.last_write
        self.bridge.save()
        self.assertGreater(self.bridge.last_write, before)
        self.bridge.state['available'] = False
        self.bridge.save(force=True)
        self.assertFalse(json.loads(self.bridge.cache.read_text())['available'])

    def test_url_filter(self):
        self.assertFalse(is_music({'url':'https://music.youtube.com.evil.test','type':'page','webSocketDebuggerUrl':'x'}))
        self.assertTrue(is_music({'url':'https://music.youtube.com/','type':'webview','webSocketDebuggerUrl':'x'}))

if __name__ == '__main__': unittest.main()
