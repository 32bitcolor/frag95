#!/usr/bin/env bash
#
# Convert the unpacked live rootfs into a proper installed system. Run by the
# Calamares installer in the target chroot near the end of the install.
#
set -uo pipefail

# Drop the live 'frag' user — the real user was created by the users module.
if id frag &>/dev/null; then
    userdel -r frag 2>/dev/null || userdel frag 2>/dev/null || true
fi

# Remove the live-only SDDM autologin drop-in (the teal theme lives in a
# separate file, 10-frag95.conf, which stays).
rm -f /etc/sddm.conf.d/20-frag95-autologin.conf

# Installed systems prompt for sudo (the live nopasswd policy is live-only).
rm -f /etc/sudoers.d/10-wheel-nopasswd

# Re-enable the screen locker the live image disabled.
rm -f /etc/xdg/kscreenlockerrc

# Remove the installer launcher.
rm -f /usr/share/applications/install-frag95.desktop

exit 0
