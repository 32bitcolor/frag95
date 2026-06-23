#!/usr/bin/env bash
#
# Assemble the Frag95 archiso profile from the upstream releng profile + our
# deltas, then build the ISO with mkarchiso. Runs inside the privileged
# frag95-builder container (see docker/Dockerfile.builder).
#
set -euo pipefail

REPO="${REPO:-/repo}"
WORK="${WORK:-/work}"
OUT="${OUT:-/out}"
PROFILE="$WORK/profile"
RELENG="/usr/share/archiso/configs/releng"

echo "==> Refreshing builder packages (archiso etc.)"
pacman -Syu --noconfirm --needed archiso rsync >/dev/null

echo "==> Seeding profile from upstream releng"
rm -rf "$WORK"
mkdir -p "$PROFILE" "$OUT"
cp -a "$RELENG/." "$PROFILE/"

echo "==> Applying Frag95 overrides"
# Replace upstream profiledef + pacman.conf with ours.
install -m 0755 "$REPO/iso/profiledef.sh" "$PROFILE/profiledef.sh"
install -m 0644 "$REPO/iso/pacman.conf"   "$PROFILE/pacman.conf"

# Append our package additions to releng's required live-boot package list.
echo "" >> "$PROFILE/packages.x86_64"
echo "# ---- Frag95 additions ----" >> "$PROFILE/packages.x86_64"
cat "$REPO/iso/packages.add.x86_64" >> "$PROFILE/packages.x86_64"

# Overlay our airootfs files on top of releng's (additive — we only add files).
rsync -a "$REPO/iso/airootfs/" "$PROFILE/airootfs/"

echo "==> Enabling services + graphical boot target (systemd symlinks)"
AIR="$PROFILE/airootfs"
# Boot into the graphical target.
ln -sf /usr/lib/systemd/system/graphical.target "$AIR/etc/systemd/system/default.target"
# SDDM as the display manager.
ln -sf /usr/lib/systemd/system/sddm.service "$AIR/etc/systemd/system/display-manager.service"
# NetworkManager for the live + installed system; mask networkd to avoid conflict.
mkdir -p "$AIR/etc/systemd/system/multi-user.target.wants"
ln -sf /usr/lib/systemd/system/NetworkManager.service \
    "$AIR/etc/systemd/system/multi-user.target.wants/NetworkManager.service"
ln -sf /dev/null "$AIR/etc/systemd/system/systemd-networkd.service"
ln -sf /dev/null "$AIR/etc/systemd/system/systemd-networkd.socket"

echo "==> Building ISO with mkarchiso"
mkarchiso -v -w "$WORK/tmp" -o "$OUT" "$PROFILE"

echo "==> Done. Output:"
ls -lh "$OUT"/*.iso
