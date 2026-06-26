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

# Chicago95's icon theme ships with no Inherits line, so any icon it lacks
# (modern Plasma tray icons like Brightness and Notifications) renders blank
# instead of falling back. Chain it to breeze (a complete theme that's already
# installed) so those icons resolve. Baked at build time, so it applies to both
# the live session and the installed system (which derives from this squashfs).
if [ -f /usr/share/icons/Chicago95/index.theme ] && \
   ! grep -q '^Inherits=' /usr/share/icons/Chicago95/index.theme; then
    sed -i '/^\[Icon Theme\]/a Inherits=hicolor,breeze' /usr/share/icons/Chicago95/index.theme
    gtk-update-icon-cache -f /usr/share/icons/Chicago95 2>/dev/null || true
fi

# Frag95 live user (uid 1000, wheel for passwordless sudo). Password is left
# locked: login is via SDDM autologin (see etc/sddm.conf.d/10-frag95.conf), and
# admin tasks / AUR makepkg use passwordless wheel sudo (etc/sudoers.d/
# 10-wheel-nopasswd). The Calamares installer creates the real, password-having
# user at install time; this user exists only on the live image.
useradd -m -u 1000 -U -G wheel -s /usr/bin/bash -c "Frag95 Live User" frag
passwd -l frag

# Put the "Install Frag95" launcher on the live user's desktop AND in autostart
# (so the installer pops up on boot). Both are done here — not via /etc/skel —
# so they stay live-only: installed users that Calamares creates from /etc/skel
# get neither an installer icon nor an auto-launching installer.
if [ -f /usr/share/applications/install-frag95.desktop ]; then
    install -d -o frag -g frag /home/frag/Desktop /home/frag/.config/autostart
    install -m 0755 -o frag -g frag \
        /usr/share/applications/install-frag95.desktop \
        /home/frag/Desktop/install-frag95.desktop
    install -m 0644 -o frag -g frag \
        /usr/share/applications/install-frag95.desktop \
        /home/frag/.config/autostart/install-frag95.desktop
fi
