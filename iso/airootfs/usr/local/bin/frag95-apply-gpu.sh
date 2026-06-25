#!/usr/bin/env bash
#
# Apply a Frag95 GPU profile to THIS system. Run by the Calamares installer
# inside the target chroot (and usable standalone post-install).
#   usage: frag95-apply-gpu.sh <profile|auto>
# Profiles live in /usr/share/frag95/gpu/ (see that dir's README). Everything is
# done via modprobe.d + mkinitcpio MODULES (no bootloader edits needed — the
# initcpio/bootloader steps run after this).
#
set -uo pipefail
GPUDIR=/usr/share/frag95/gpu
profile="${1:-auto}"

if [ "$profile" = auto ]; then
    profile="$( "$GPUDIR/auto/detect.sh" 2>/dev/null || echo vm )"
fi
src="$GPUDIR/$profile"
if [ ! -d "$src" ]; then
    echo "frag95-apply-gpu: unknown profile '$profile' — skipping." >&2
    exit 0
fi
echo "frag95-apply-gpu: applying GPU profile '$profile'"

# 1) modprobe.d options (nvidia_drm modeset=1, GSP fallback, etc.)
if [ -f "$src/modprobe.conf" ]; then
    install -Dm0644 "$src/modprobe.conf" /etc/modprobe.d/frag95-gpu.conf
fi

# 2) early-KMS modules into mkinitcpio's MODULES=( ... ) (initcpio step rebuilds)
if [ -f "$src/modules" ] && [ -f /etc/mkinitcpio.conf ]; then
    mods="$(grep -vE '^\s*#' "$src/modules" | tr '\n' ' ')"
    mods="$(echo "$mods" | xargs)"   # trim
    if [ -n "$mods" ]; then
        sed -i -E "s|^MODULES=\((.*)\)|MODULES=(\1 ${mods})|" /etc/mkinitcpio.conf
    fi
fi

# 3) profile driver package(s): the live image ships nvidia-open-dkms; legacy
#    swaps to nvidia-470xx-dkms (from [frag95]). Best-effort, offline.
if [ -f "$src/pkgs" ]; then
    while read -r p; do
        [ -z "$p" ] && continue
        pacman -S --noconfirm --needed "$p" 2>/dev/null || true
    done < "$src/pkgs"
fi

echo "frag95-apply-gpu: done ($profile)."
exit 0
