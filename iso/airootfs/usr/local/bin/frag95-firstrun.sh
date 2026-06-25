#!/usr/bin/env bash
#
# Apply the Frag95 (Windows 9x) global theme on first login, then bow out.
# The color scheme, widget style, fonts and window decoration are already set
# in skel's kdeglobals/kwinrc; this step applies the *layout* the static config
# can't — the bottom taskbar (Start menu, task list, tray, clock) and the teal
# desktop from the look-and-feel's layout.js. It self-disables after one run.
#
flag="${XDG_CONFIG_HOME:-$HOME/.config}/frag95-theme-applied"
[ -e "$flag" ] && exit 0

# --resetLayout makes plasmashell load the look-and-feel's panel layout.
plasma-apply-lookandfeel --apply org.frag95.redmond --resetLayout >/dev/null 2>&1 || true

mkdir -p "$(dirname "$flag")"
: > "$flag"
