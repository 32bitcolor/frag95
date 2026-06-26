#!/usr/bin/env bash
#
# Generate the Frag95 "Win9x-style" system sound theme.
#
# These are ORIGINAL sounds synthesized from scratch with sox — simple chimes,
# chords and blips that *evoke* the Windows 9x era without being the literal
# (copyrighted) Microsoft .wav files. That keeps the public repo clean: every
# file here is a generated original work, free to redistribute.
#
# Output: iso/airootfs/usr/share/sounds/frag95/stereo/*.oga  (freedesktop layout)
#
# Run it inside an Arch container that has sox + vorbis-tools, e.g.:
#   docker run --rm -v "$PWD:/repo" -w /repo archlinux bash -c \
#     'pacman -Sy --noconfirm sox vorbis-tools >/dev/null && bash scripts/gen-sounds.sh'
#
set -euo pipefail

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$REPO/iso/airootfs/usr/share/sounds/frag95/stereo"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$OUT"

# Note frequencies (Hz)
C3=130.81; E3=164.81; G3=196.00
C4=261.63;            G4=392.00; A4=440.00
C5=523.25; D5=587.33; E5=659.25; G5=783.99; B5=987.77

# All intermediate files are 16-bit signed PCM so oggenc never sees a float/odd
# subformat. `gain -14` after each remix buys headroom so reverb doesn't clip;
# the encode step normalizes every file back up to a consistent -3 dB peak.
S() { sox -n -r 44100 -c 1 -b 16 -e signed-integer "$@"; }

echo "==> Synthesizing Frag95 sounds into $OUT"

# --- login : warm major-chord swell (the iconic "boot" chime) -----------------
S "$T/login.wav" synth 2.4 sine $C4 sine $G4 sine $C5 sine $E5 \
    remix - gain -14 reverb 60 50 100 fade t 0.7 2.4 1.5

# --- logout : gentle descending chord (power down) ----------------------------
S "$T/lo1.wav" synth 0.45 sine $C5 sine $E5 remix - gain -8 fade t 0.01 0.45 0.4
S "$T/lo2.wav" synth 0.45 sine $G4 sine $C5 remix - gain -8 fade t 0.01 0.45 0.4
S "$T/lo3.wav" synth 0.9  sine $C4 sine $G4 remix - gain -8 fade t 0.01 0.9 0.85
sox "$T/lo1.wav" "$T/lo2.wav" "$T/lo3.wav" "$T/logout.wav" reverb 40

# --- bell / message : soft single "ding" (notifications) ----------------------
S "$T/bell.wav" synth 0.6 sine $B5 sine $E5 remix - gain -8 fade t 0.004 0.6 0.55 reverb 20

# --- complete : rising "ta-daa" (task finished) -------------------------------
S "$T/c1.wav" synth 0.16 sine $G4 gain -6 fade t 0.005 0.16 0.06
S "$T/c2.wav" synth 0.6  sine $C5 sine $E5 sine $G5 remix - gain -12 fade t 0.005 0.6 0.5 reverb 25
sox "$T/c1.wav" "$T/c2.wav" "$T/complete.wav"

# --- error : low dissonant "dun-dun" (critical stop) --------------------------
S "$T/e1.wav" synth 0.22 sine $G3 sine $C3 remix - gain -8 fade t 0.005 0.22 0.08
S "$T/e2.wav" synth 0.55 sine $E3 sine 110 remix - gain -10 fade t 0.005 0.55 0.45
sox "$T/e1.wav" "$T/e2.wav" "$T/error.wav" reverb 15

# --- warning : firm mid chime (exclamation) -----------------------------------
S "$T/warn.wav" synth 0.45 sine $D5 sine $A4 remix - gain -8 fade t 0.004 0.45 0.4 reverb 15

# --- info / question : gentle rising two-tone ---------------------------------
S "$T/i1.wav" synth 0.14 sine $C5 gain -6 fade t 0.005 0.14 0.06
S "$T/i2.wav" synth 0.4  sine $E5 gain -6 fade t 0.005 0.4 0.35 reverb 15
sox "$T/i1.wav" "$T/i2.wav" "$T/info.wav"

# --- device-added : quick rising blip (USB plug in) ---------------------------
S "$T/d1.wav" synth 0.07 sine $E5 gain -6 fade t 0.004 0.07 0.03
S "$T/d2.wav" synth 0.10 sine $B5 gain -6 fade t 0.004 0.10 0.05
sox "$T/d1.wav" "$T/d2.wav" "$T/device-added.wav"

# --- device-removed : quick falling blip (USB unplug) -------------------------
S "$T/r1.wav" synth 0.07 sine $B5 gain -6 fade t 0.004 0.07 0.03
S "$T/r2.wav" synth 0.10 sine $E5 gain -6 fade t 0.004 0.10 0.05
sox "$T/r1.wav" "$T/r2.wav" "$T/device-removed.wav"

# --- trash-empty : short filtered whoosh (empty recycle bin) ------------------
S "$T/trash-empty.wav" synth 0.4 whitenoise fade t 0.01 0.4 0.39 \
    lowpass 1400 highpass 350 gain -8

# Encode every base .wav to a normalized stereo .oga, mapped to freedesktop
# sound names (so libcanberra / GTK / KDE all resolve them by event).
declare -A MAP=(
    [login]="desktop-login service-login"
    [logout]="desktop-logout service-logout system-shutdown"
    [bell]="bell message message-new-instant"
    [complete]="complete"
    [error]="dialog-error"
    [warn]="dialog-warning window-attention"
    [info]="dialog-information dialog-question"
    [device-added]="device-added"
    [device-removed]="device-removed"
    [trash-empty]="trash-empty"
)
for base in "${!MAP[@]}"; do
    sox "$T/$base.wav" -b 16 -e signed-integer -c 2 "$T/$base.st.wav" gain -n -3
    for name in ${MAP[$base]}; do
        oggenc -Q -q 5 -o "$OUT/$name.oga" "$T/$base.st.wav"
    done
done

echo "==> Done. Generated:"
ls -1 "$OUT"
