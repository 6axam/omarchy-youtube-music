#!/usr/bin/env bash
# Install the plugin and its user service; browser configuration is separate.
set -euo pipefail
id=6axam.youtube-music
repo=https://github.com/6axam/omarchy-youtube-music.git
plugin="$HOME/.config/omarchy/plugins/$id"
unit="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/omarchy-youtube-music.service"
fail() { printf 'install: %s\n' "$*" >&2; exit 1; }

for cmd in omarchy omarchy-shell git systemctl; do
  command -v "$cmd" >/dev/null || fail "Required command not found: $cmd (Omarchy with Quickshell is required)."
done
[[ -x /usr/bin/python ]] || fail '/usr/bin/python is required.'
if ! /usr/bin/python -c 'import aiohttp' 2>/dev/null; then
  printf '%s\n' 'The bridge needs python-aiohttp. Installing it with omarchy pkg add python-aiohttp.'
  if [[ ! -t 0 && -r /dev/tty ]]; then
    omarchy pkg add python-aiohttp </dev/tty || fail 'Dependency installation failed. Run: omarchy pkg add python-aiohttp'
  else
    omarchy pkg add python-aiohttp || fail 'Dependency installation failed. Run: omarchy pkg add python-aiohttp'
  fi
  /usr/bin/python -c 'import aiohttp' 2>/dev/null || fail 'python-aiohttp is still unavailable to /usr/bin/python.'
fi
if [[ -e $plugin || -L $plugin ]]; then
  [[ -d $plugin/.git && ! -L $plugin ]] || fail "Existing plugin path is not this project's git checkout: $plugin"
  origin=$(git -C "$plugin" remote get-url origin 2>/dev/null || true)
  case "$origin" in
    "$repo"|https://github.com/6axam/omarchy-youtube-music|git@github.com:6axam/omarchy-youtube-music.git|git@github.com:6axam/omarchy-youtube-music) ;;
    *) fail "Existing plugin has a different origin ($origin); leaving it untouched: $plugin" ;;
  esac
  printf '%s\n' "Using existing checkout at $plugin; update explicitly with: omarchy plugin update $id"
  omarchy plugin enable "$id" || fail "Could not enable $id."
else
  omarchy plugin add "$repo" --enable --yes || fail 'Plugin installation failed.'
fi
[[ -f $plugin/bridge/bridge.py ]] || fail "Bridge missing in checkout: $plugin/bridge/bridge.py"
if [[ -e $unit || -L $unit ]]; then
  [[ -f $unit && ! -L $unit ]] && grep -qx '# Managed by omarchy-youtube-music installer' "$unit" || fail "Refusing to overwrite existing unit: $unit"
fi
mkdir -p "$(dirname "$unit")"
# systemd command quoting: double backslashes/quotes and literal % specifiers.
/usr/bin/python - "$plugin/bridge/bridge.py" "$unit" <<'PY'
import os, sys, tempfile
script, unit = sys.argv[1:]
def quote(s):
    return '"' + s.replace('\\', '\\\\').replace('"', '\\"').replace('%', '%%') + '"'
content = f'''# Managed by omarchy-youtube-music installer
[Unit]
Description=Omarchy YouTube Music bridge
After=graphical-session.target
PartOf=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/bin/python {quote(script)}
Restart=on-failure
RestartSec=3

[Install]
WantedBy=graphical-session.target
'''
fd, path = tempfile.mkstemp(prefix='.omarchy-youtube-music.', dir=os.path.dirname(unit), text=True)
try:
    with os.fdopen(fd, 'w') as f:
        f.write(content)
    os.replace(path, unit)
except BaseException:
    try: os.unlink(path)
    except FileNotFoundError: pass
    raise
PY
systemctl --user daemon-reload || fail 'Could not reload user systemd.'
systemctl --user enable --now omarchy-youtube-music.service || fail 'Could not enable/start bridge; inspect: systemctl --user status omarchy-youtube-music.service'
# Reinstalling should load the current bridge and unit as well.
systemctl --user restart omarchy-youtube-music.service || fail 'Bridge restart failed; inspect: systemctl --user status omarchy-youtube-music.service'
printf '\n%s\n' 'Installed. Browser access requires an explicit setup step:' \
  "  bash \"$plugin/setup-browser.sh\"" \
  'The setup prints how to launch your existing Opera GX profile with debugging enabled.'
