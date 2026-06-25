#!/usr/bin/env bash
#
# Reference GPU auto-detection for the "Auto" installer choice. Prints exactly
# one profile name (nvidia | amd | hybrid | vm | intel) on stdout. The Phase 6
# Calamares installer uses this to resolve "Auto" to a concrete profile under
# /usr/share/frag95/gpu/. Pure detection — it changes nothing.
#
set -euo pipefail

# Virtual machine? virtio/QXL/etc. — use the vm profile regardless of vGPU.
if systemd-detect-virt --quiet 2>/dev/null; then
    echo vm; exit 0
fi

have() { lspci -nn 2>/dev/null | grep -iE 'VGA|3D|Display' | grep -iqE "$1"; }

nvidia=0; amd=0; intel=0
have 'NVIDIA'            && nvidia=1
have 'AMD|ATI|Radeon'   && amd=1
have 'Intel'            && intel=1

# NVIDIA dGPU alongside an Intel/AMD iGPU => Optimus/hybrid.
if (( nvidia && (intel || amd) )); then echo hybrid; exit 0; fi
if (( nvidia )); then echo nvidia; exit 0; fi
if (( amd ));    then echo amd;    exit 0; fi
if (( intel ));  then echo intel;  exit 0; fi

# Unknown GPU: fall back to the generic Mesa/modesetting (vm) profile, which is
# the most conservative and always boots.
echo vm
