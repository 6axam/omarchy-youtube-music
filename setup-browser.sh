#!/usr/bin/env bash
# Opt-in browser launcher. This does not change the default browser or restart it.
set -euo pipefail
target="${XDG_DATA_HOME:-$HOME/.local/share}/omarchy-youtube-music/bin/omarchy-youtube-music-browser"
fail() { printf 'setup-browser: %s\n' "$*" >&2; exit 1; }
browser=${OPERA_GX_COMMAND:-$(command -v opera-gx || true)}
[[ -n $browser && $browser = /* && -x $browser ]] || fail 'Cannot find opera-gx. Set OPERA_GX_COMMAND to the absolute path of your existing executable or wrapper.'
[[ $(readlink -f -- "$browser") != "$(readlink -m -- "$target")" ]] || fail 'The browser command resolves to the generated launcher itself.'
if [[ -e $target || -L $target ]]; then
  [[ -f $target && ! -L $target ]] && grep -qx '# Managed by omarchy-youtube-music installer' "$target" || fail "Refusing to overwrite existing file: $target"
fi
mkdir -p "$(dirname "$target")"
tmp=$(mktemp "${target}.XXXXXX")
trap 'rm -f -- "$tmp"' EXIT
{
  printf '%s\n' '#!/usr/bin/env bash' '# Managed by omarchy-youtube-music installer'
  printf 'exec %q --remote-debugging-address=127.0.0.1 --remote-debugging-port=9222 "$@"\n' "$browser"
} >"$tmp"
chmod 755 "$tmp"
mv -f -- "$tmp" "$target"
trap - EXIT
if ! /usr/bin/python - <<'PY'
import socket
s = socket.socket()
try:
    s.bind(('127.0.0.1', 9222))
except OSError:
    raise SystemExit(1)
finally:
    s.close()
PY
then
  printf '%s\n' 'Warning: 127.0.0.1:9222 is already in use. Identify the listener before using this launcher; it was not stopped.' >&2
fi
printf '\n%s\n' "Created launcher: $target" \
  "It delegates to: $browser" \
  'Close Opera GX yourself, then launch it with the command above; Chromium may ignore debugging flags if an existing process is still running.' \
  'Your browser profile and default launcher are unchanged. This exposes browser debugging to local programs.'
