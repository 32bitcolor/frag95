#!/usr/bin/env bash
#
# Play a Frag95 system sound by freedesktop name, using whatever audio player
# is on hand. Usage: frag95-play-sound.sh <sound-name>   (e.g. desktop-login)
#
# Tries the PipeWire/PulseAudio players first, then libcanberra, then ALSA.
# Stays quiet (and exits 0) if nothing can play — a missing sound should never
# break login or spam errors.
#
set -uo pipefail
name="${1:-bell}"
f="/usr/share/sounds/frag95/stereo/${name}.oga"
[ -r "$f" ] || exit 0

if   command -v pw-play         >/dev/null 2>&1; then exec pw-play "$f"
elif command -v paplay          >/dev/null 2>&1; then exec paplay "$f"
elif command -v canberra-gtk-play >/dev/null 2>&1; then exec canberra-gtk-play -f "$f"
elif command -v ffplay          >/dev/null 2>&1; then exec ffplay -nodisp -autoexit -loglevel quiet "$f"
elif command -v ogg123          >/dev/null 2>&1; then exec ogg123 -q "$f"
fi
exit 0
