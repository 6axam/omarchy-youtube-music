#!/usr/bin/env python3
"""Send one JSON command, returning one JSON response."""
import argparse
import json
import os
import socket
import sys

p = argparse.ArgumentParser()
p.add_argument('command', choices=['state','playPause','play','pause','next','previous','select','seek','shuffle','repeat','bind'])
p.add_argument('--session-id')
p.add_argument('--index', type=int)
p.add_argument('--id')
p.add_argument('--position', type=float)
a = p.parse_args()
request = {'command':a.command}
for key, value in [('sessionId',a.session_id),('index',a.index),('id',a.id),('position',a.position)]:
    if value is not None: request[key] = value
try:
    with socket.socket(socket.AF_UNIX) as s:
        s.settimeout(5)
        s.connect(os.path.join(os.environ.get('XDG_RUNTIME_DIR') or f'/run/user/{os.getuid()}', 'omarchy-youtube-music.sock'))
        s.sendall((json.dumps(request, allow_nan=False)+'\n').encode())
        with s.makefile('r', encoding='utf-8') as f:
            response = json.loads(f.readline())
    print(json.dumps(response, ensure_ascii=False))
    sys.exit(0 if response.get('ok') else 1)
except (OSError, ValueError) as e:
    print(json.dumps({'ok':False,'error':str(e)}))
    sys.exit(1)
