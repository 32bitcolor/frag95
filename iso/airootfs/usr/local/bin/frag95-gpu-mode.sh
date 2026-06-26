#!/usr/bin/env bash
#
# Frag95 GPU Mode — a simple GUI to switch a hybrid (Optimus) laptop's GPU mode.
#
# It's a thin kdialog front-end over `envycontrol`, which does the real work of
# reconfiguring the NVIDIA/Intel setup. Three modes:
#   integrated  Intel iGPU only        — best battery, NVIDIA powered off
#   hybrid      Intel + NVIDIA on demand — the Frag95 default (PRIME offload)
#   nvidia      NVIDIA dGPU only        — max performance, more power draw
#
# For running a single game on the dGPU you usually DON'T need this — just
# right-click the app and pick "Run with dedicated GPU" (switcheroo-control).
# Use this when you want to change the whole system's mode (e.g. NVIDIA-only for
# an external monitor, or integrated-only to save battery). Changes need a reboot.
#
set -uo pipefail

if ! command -v envycontrol >/dev/null 2>&1; then
    kdialog --title "Frag95 GPU Mode" --error \
        "This tool is for hybrid (Optimus) laptops with both an Intel and an NVIDIA GPU.\n\nenvycontrol isn't installed, so there's nothing to switch." 2>/dev/null
    exit 1
fi

current="$(envycontrol --query 2>/dev/null | tr -d '[:space:]')"
[ -z "$current" ] && current="unknown"

# Pre-select the current mode in the radiolist.
i_on=off; h_on=off; n_on=off
case "$current" in
    integrated) i_on=on ;;
    hybrid)     h_on=on ;;
    nvidia)     n_on=on ;;
    *)          h_on=on ;;
esac

choice="$(kdialog --title "Frag95 GPU Mode" --radiolist \
    "Current mode: ${current}\n\nPick a GPU mode (takes effect after a reboot):" \
    integrated "Integrated — Intel only (best battery)" "$i_on" \
    hybrid     "Hybrid — Intel + NVIDIA on demand (default)" "$h_on" \
    nvidia     "NVIDIA — dedicated GPU only (max performance)" "$n_on" \
    2>/dev/null)" || exit 0

[ -z "$choice" ] && exit 0
[ "$choice" = "$current" ] && {
    kdialog --title "Frag95 GPU Mode" --msgbox "Already in '${choice}' mode — nothing to do." 2>/dev/null
    exit 0
}

log=/tmp/frag95-gpu-mode.log
if pkexec envycontrol --switch "$choice" >"$log" 2>&1; then
    if kdialog --title "Frag95 GPU Mode" --yesno \
        "Switched to '${choice}' mode.\n\nThe change applies after a reboot. Reboot now?" 2>/dev/null; then
        pkexec systemctl reboot
    fi
else
    kdialog --title "Frag95 GPU Mode" --error \
        "Couldn't switch GPU mode.\n\nDetails in ${log}" 2>/dev/null
    exit 1
fi
