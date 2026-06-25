#!/usr/bin/env bash
#
# Build-time airootfs customization, run by mkarchiso inside the chroot during
# _make_customize_airootfs (then deleted from the image, so it never ships).
#
# Why this instead of a sysusers.d drop-in: creating the live user here, at
# build time, bakes it into the squashfs /etc/passwd (so scripts/verify-iso.sh
# can confirm it) AND `useradd -m` copies /etc/skel into the home directory --
# which is how Phase 5's Windows-9x Plasma theming (shipped via skel ~/.config)
# will reach the live session. A boot-time sysusers.d user would get neither.
#
set -euo pipefail

# Frag95 live user (uid 1000, wheel for passwordless sudo). Password is left
# locked: login is via SDDM autologin (see etc/sddm.conf.d/10-frag95.conf), and
# admin tasks / AUR makepkg use passwordless wheel sudo (etc/sudoers.d/
# 10-wheel-nopasswd). The Calamares installer creates the real, password-having
# user at install time; this user exists only on the live image.
useradd -m -u 1000 -U -G wheel -s /usr/bin/bash -c "Frag95 Live User" frag
passwd -l frag

# Put the "Install Frag95" launcher on the live user's desktop. This is done
# here (not via /etc/skel) so it stays live-only — installed users that
# Calamares creates from /etc/skel don't get an installer icon.
if [ -f /usr/share/applications/install-frag95.desktop ]; then
    install -d -o frag -g frag /home/frag/Desktop
    install -m 0755 -o frag -g frag \
        /usr/share/applications/install-frag95.desktop \
        /home/frag/Desktop/install-frag95.desktop
fi
