#!/usr/bin/env bash
#
# Frag95 Performance — a kdialog picker for the performance/cooling profile.
# Calls the privileged frag95-performance.sh via pkexec (a polkit rule lets
# wheel users run it without a password).
#
set -uo pipefail
cur="$(cat /var/lib/frag95/performance-profile 2>/dev/null || echo balanced)"
on() { [ "$cur" = "$1" ] && echo on || echo off; }

sel="$(kdialog --title "Frag95 Performance" --radiolist \
    "Current: ${cur}\n\nPick a performance / cooling profile:" \
    silent      "Silent — quietest, coolest-running (throttled)"        "$(on silent)" \
    balanced    "Balanced — the default"                                "$(on balanced)" \
    performance "Performance — aggressive fans + full CPU speed"        "$(on performance)" \
    extreme     "Extreme — Cooler Boost (max fans) + full speed"        "$(on extreme)" \
    2>/dev/null)" || exit 0
[ -z "$sel" ] && exit 0

if pkexec /usr/local/bin/frag95-performance.sh "$sel" >/dev/null 2>&1; then
    kdialog --title "Frag95 Performance" --passivepopup "Switched to: ${sel}" 4 2>/dev/null
else
    kdialog --title "Frag95 Performance" --error "Could not apply the '${sel}' profile." 2>/dev/null
fi
