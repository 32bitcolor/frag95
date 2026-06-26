#!/usr/bin/env bash
#
# Restore the Frag95 (Windows 9x) desktop theme — the out-of-box look.
#
# Run this any time the appearance got changed (e.g. by toggling Dark Mode, or
# fiddling in System Settings) to get the Win95 look back. It re-applies the
# global theme + the Win95 panel layout, and pins BOTH the light and dark
# "global theme" slots to Frag95 so the Dark Mode toggle keeps the Win95 look
# instead of reverting to Breeze.
#
set -uo pipefail
LNF=org.frag95.redmond

# Make the Dark Mode toggle harmless: both day/night slots use our theme.
kwriteconfig6 --file kdeglobals --group KDE --key DefaultLightLookAndFeel "$LNF" 2>/dev/null || true
kwriteconfig6 --file kdeglobals --group KDE --key DefaultDarkLookAndFeel  "$LNF" 2>/dev/null || true

# Re-apply the global theme (colours, decoration, plasma theme, icons, cursor,
# widget style) and reset the panel layout to the Win95 taskbar.
plasma-apply-lookandfeel --apply "$LNF" --resetLayout 2>/dev/null || true

# Disable the KDE startup splash ("powered by KDE"). Applying the look-and-feel
# can clear ksplashrc back to the default Breeze splash, so pin it off here,
# after the apply, where it sticks.
kwriteconfig6 --file ksplashrc --group KSplash --key Theme None   2>/dev/null || true
kwriteconfig6 --file ksplashrc --group KSplash --key Engine none  2>/dev/null || true
