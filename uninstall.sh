#!/usr/bin/env bash
# Disable integration and remove only files bearing our ownership marker.
set -euo pipefail
id=6axam.youtube-music
unit="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/omarchy-youtube-music.service"
launcher="${XDG_DATA_HOME:-$HOME/.local/share}/omarchy-youtube-music/bin/omarchy-youtube-music-browser"
if command -v omarchy >/dev/null && [[ -e $HOME/.config/omarchy/plugins/$id ]]; then
  omarchy plugin disable "$id" || printf '%s\n' 'Could not disable plugin; check Omarchy shell and run: omarchy plugin disable 6axam.youtube-music' >&2
fi
if [[ -f $unit && ! -L $unit ]] && grep -qx '# Managed by omarchy-youtube-music installer' "$unit"; then
  systemctl --user disable --now omarchy-youtube-music.service || { printf '%s\n' 'Could not stop/disable service; unit retained.' >&2; exit 1; }
  rm -- "$unit"
  systemctl --user daemon-reload
elif [[ -e $unit || -L $unit ]]; then
  printf 'Leaving unrecognized unit untouched: %s\n' "$unit" >&2
fi
if [[ -f $launcher && ! -L $launcher ]] && grep -qx '# Managed by omarchy-youtube-music installer' "$launcher"; then
  rm -- "$launcher"
elif [[ -e $launcher || -L $launcher ]]; then
  printf 'Leaving unrecognized launcher untouched: %s\n' "$launcher" >&2
fi
printf '%s\n' 'Integration disabled. The plugin checkout is retained; remove it explicitly with: omarchy plugin remove 6axam.youtube-music' \
  'Browser profile and cached music data were retained.'
