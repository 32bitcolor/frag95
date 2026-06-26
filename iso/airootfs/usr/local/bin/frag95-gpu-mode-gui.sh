#!/usr/bin/env bash
#
# Frag95 GPU Mode — a kdialog picker (Start-menu launcher) for the hybrid-GPU
# mode. The tray plasmoid (org.frag95.gpumode) is the primary UI; this mirrors
# it for the application menu. Calls the privileged frag95-gpu-mode.sh via pkexec
# (the 49-frag95-gpu-mode polkit rule = no password for wheel).
#
set -uo pipefail

if ! command -v envycontrol >/dev/null 2>&1; then
    kdialog --title "Frag95 GPU Mode" --error \
        "This is for hybrid (Optimus) laptops with both Intel and NVIDIA GPUs.\nenvycontrol isn't installed, so there's nothing to switch." 2>/dev/null
    exit 1
fi

cur="$(/usr/local/bin/frag95-gpu-mode.sh query 2>/dev/null)"
[ -z "$cur" ] && cur="unknown"
on() { [ "$cur" = "$1" ] && echo on || echo off; }

sel="$(kdialog --title "Frag95 GPU Mode" --radiolist \
    "Current mode: ${cur}\n\nPick a GPU mode (takes effect after a reboot):" \
    integrated "Integrated — Intel only (best battery)"            "$(on integrated)" \
    hybrid     "Hybrid — Intel + NVIDIA on demand (default)"       "$(on hybrid)" \
    nvidia     "NVIDIA — dedicated GPU only (max performance)"     "$(on nvidia)" \
    2>/dev/null)" || exit 0
[ -z "$sel" ] && exit 0
[ "$sel" = "$cur" ] && { kdialog --title "Frag95 GPU Mode" --msgbox "Already in '${sel}' mode." 2>/dev/null; exit 0; }

if pkexec /usr/local/bin/frag95-gpu-mode.sh "$sel" >/tmp/frag95-gpu-mode.log 2>&1; then
    if kdialog --title "Frag95 GPU Mode" --yesno "Switched to '${sel}'.\nApplies after a reboot. Reboot now?" 2>/dev/null; then
        pkexec systemctl reboot
    fi
else
    kdialog --title "Frag95 GPU Mode" --error "Couldn't switch GPU mode. See /tmp/frag95-gpu-mode.log" 2>/dev/null
fi
