#!/usr/bin/env bash
#
# Frag95 GPU Mode — switch a hybrid (Optimus) laptop's GPU mode via envycontrol.
#
#   frag95-gpu-mode.sh {integrated|hybrid|nvidia|query}
#
#   integrated  Intel iGPU only          — best battery, NVIDIA off
#   hybrid      Intel + NVIDIA on demand  — the Frag95 default (PRIME offload)
#   nvidia      NVIDIA dGPU only          — max performance, more power draw
#
# A switch rewrites persistent display/driver configs and needs a REBOOT to take
# effect. The switch needs root (callers run it via pkexec + the 49-frag95-gpu-
# mode polkit rule); `query` is read-only. This is the privileged backend for
# the tray plasmoid (org.frag95.gpumode) and the kdialog launcher.
#
set -uo pipefail

command -v envycontrol >/dev/null 2>&1 || { echo "envycontrol-missing"; exit 1; }

case "${1:-query}" in
    query|status)
        envycontrol --query 2>/dev/null | tr -d '[:space:]' ;;
    integrated|hybrid|nvidia)
        envycontrol --switch "$1" ;;
    *)
        echo "usage: ${0##*/} {integrated|hybrid|nvidia|query}" >&2; exit 2 ;;
esac
