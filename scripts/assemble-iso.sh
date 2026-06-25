#!/usr/bin/env bash
#
# Assemble the Frag95 archiso profile from the upstream releng profile + our
# deltas (iso/), then build the ISO with mkarchiso.
#
# This is the OS-agnostic build core. It runs either:
#   * inside the privileged frag95-builder container (scripts/build-in-container.sh), or
#   * natively on an Arch-based host that has `archiso` installed (build.sh --engine native).
#
# It does NOT install packages or assume a container — it expects archiso +
# rsync to already be present and to run as root (mkarchiso requires root).
#
set -euo pipefail

REPO="${REPO:-/repo}"
WORK="${WORK:-/work}"
OUT="${OUT:-/out}"
PROFILE="$WORK/profile"
RELENG="${RELENG:-/usr/share/archiso/configs/releng}"

# --- Preconditions (fail early with actionable messages) ---------------------
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "!! assemble-iso.sh must run as root (mkarchiso needs root)." >&2
    echo "   Use build.sh, which handles sudo/container privileges for you." >&2
    exit 1
fi
for tool in mkarchiso rsync; do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "!! '$tool' not found. Install 'archiso' and 'rsync'." >&2
        exit 1
    }
done
if [[ ! -d "$RELENG" ]]; then
    echo "!! Upstream releng profile not found at: $RELENG" >&2
    echo "   It ships with the 'archiso' package; set RELENG= to override." >&2
    exit 1
fi

echo "==> Seeding profile from upstream releng ($RELENG)"
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
