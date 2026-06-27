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
# Replace upstream profiledef + pacman.conf with ours (used by pacstrap)...
install -m 0755 "$REPO/iso/profiledef.sh" "$PROFILE/profiledef.sh"
install -m 0644 "$REPO/iso/pacman.conf"   "$PROFILE/pacman.conf"
# ...and ship the same pacman.conf to the LIVE system, so multilib + the
# [frag95] repo are enabled there too (pacstrap's default /etc/pacman.conf
# would otherwise leave them off on the installed live image).
install -D -m 0644 "$REPO/iso/pacman.conf" "$PROFILE/airootfs/etc/pacman.conf"

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
# Thermal + power management for the installed system. thermald proactively
# manages Intel CPU power/thermal limits (better sustained performance, lower
# temps under load); power-profiles-daemon gives KDE the Performance/Balanced/
# Power-Saver slider. Both ship in packages.add.x86_64.
ln -sf /usr/lib/systemd/system/thermald.service \
    "$AIR/etc/systemd/system/multi-user.target.wants/thermald.service"
mkdir -p "$AIR/etc/systemd/system/graphical.target.wants"
ln -sf /usr/lib/systemd/system/power-profiles-daemon.service \
    "$AIR/etc/systemd/system/graphical.target.wants/power-profiles-daemon.service"
# Re-apply the saved Frag95 performance/cooling profile on boot (the MSI EC
# resets each boot). Unit ships in airootfs/usr/lib/systemd/system/.
ln -sf /usr/lib/systemd/system/frag95-performance.service \
    "$AIR/etc/systemd/system/multi-user.target.wants/frag95-performance.service"
# switcheroo-control: powers Plasma's "Run with dedicated GPU" menu entry on
# hybrid laptops. It's D-Bus activated but Plasma needs it running to offer the
# option, so enable it explicitly.
ln -sf /usr/lib/systemd/system/switcheroo-control.service \
    "$AIR/etc/systemd/system/graphical.target.wants/switcheroo-control.service"

# Expose the bundled [frag95] repo to pacstrap. Our pacman.conf points [frag95]
# at file:///var/lib/frag95-repo (the path on the live system); make that same
# path resolve on the build host so pacstrap can install paru/octopi from it.
# build-localrepo.sh populates iso/airootfs/var/lib/frag95-repo beforehand; if
# it's empty we still create an empty db so the enabled repo can't break pacstrap.
FRAG_REPO_SRC="$REPO/iso/airootfs/var/lib/frag95-repo"
echo "==> Exposing [frag95] local repo for pacstrap"
mkdir -p /var/lib/frag95-repo
if [[ -e "$FRAG_REPO_SRC/frag95.db" ]]; then
    cp -af "$FRAG_REPO_SRC/." /var/lib/frag95-repo/
    echo "    $(find "$FRAG_REPO_SRC" -name '*.pkg.tar.*' | wc -l | tr -d ' ') package file(s) from $FRAG_REPO_SRC"
else
    echo "    WARNING: no built repo at $FRAG_REPO_SRC — creating an empty db." >&2
    echo "    Run scripts/build-localrepo.sh first to populate paru/octopi/etc." >&2
    ( cd /var/lib/frag95-repo && repo-add frag95.db.tar.gz >/dev/null 2>&1 || true )
fi

echo "==> Building ISO with mkarchiso"
mkarchiso -v -w "$WORK/tmp" -o "$OUT" "$PROFILE"

echo "==> Done. Output:"
ls -lh "$OUT"/*.iso
