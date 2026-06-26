#!/usr/bin/env bash
#
# Correct-by-construction check of a built Frag95 ISO: extract the rootfs
# squashfs + package manifest and confirm our customizations actually landed
# (Phase 1 live system; Phase 2 GPU driver stacks + profiles).
#
set -uo pipefail

OUT="${OUT:-/out}"
ISO="$(ls -t "$OUT"/*.iso 2>/dev/null | head -n1)"
if [[ -z "$ISO" ]]; then echo "!! No ISO in $OUT"; exit 1; fi
echo "==> ISO: $ISO"

echo "==> Extracting airootfs.sfs"
osirrox -indev "$ISO" -extract /frag95/x86_64/airootfs.sfs /tmp/a.sfs >/dev/null 2>&1

echo "==> Unsquashing config paths"
rm -rf /tmp/r
unsquashfs -n -f -d /tmp/r /tmp/a.sfs \
    etc/passwd etc/shadow \
    etc/sddm.conf.d etc/sudoers.d etc/xdg/kscreenlockerrc \
    etc/systemd/system usr/share/xsessions usr/share/frag95 \
    etc/pacman.conf var/lib/frag95-repo \
    etc/skel usr/share/color-schemes usr/share/plasma/look-and-feel \
    usr/local/bin usr/share/sddm/themes/breeze \
    usr/share/aurorae usr/share/plasma/desktoptheme/reactplus \
    usr/share/themes/Chicago95 usr/share/icons/Chicago95_Standard_Cursors \
    etc/calamares usr/share/applications >/dev/null 2>&1

echo "==> Extracting package manifest"
osirrox -indev "$ISO" -extract /frag95/pkglist.x86_64.txt /tmp/pkglist >/dev/null 2>&1
pkg() { grep -qE "^$1 " /tmp/pkglist; }   # pkglist.x86_64.txt lines are "name version"

R=/tmp/r
pass=0; fail=0
check() { # desc, test-expr already evaluated -> $1 desc, $2 result(0/1)
    if [[ "$2" == "0" ]]; then echo "  [PASS] $1"; pass=$((pass+1));
    else echo "  [FAIL] $1"; fail=$((fail+1)); fi
}

echo "===== RESULTS ====="
grep -qE '^frag:x:1000:' "$R/etc/passwd"; check "live user 'frag' (uid 1000) exists" $?
grep -qE '^frag:' "$R/etc/shadow"; check "frag has a shadow entry" $?
grep -q 'User=frag' "$R/etc/sddm.conf.d/20-frag95-autologin.conf"; check "SDDM autologin user=frag" $?
grep -q 'Session=plasmax11' "$R/etc/sddm.conf.d/20-frag95-autologin.conf"; check "SDDM session=plasmax11 (X11 default)" $?
[[ -f "$R/usr/share/xsessions/plasmax11.desktop" ]]; check "plasmax11.desktop session file present" $?
grep -q '%wheel.*NOPASSWD' "$R/etc/sudoers.d/10-wheel-nopasswd"; check "passwordless wheel sudo" $?
grep -q 'Autolock=false' "$R/etc/xdg/kscreenlockerrc"; check "screen lock disabled" $?
[[ "$(readlink "$R/etc/systemd/system/default.target")" == *graphical.target ]]; check "default.target -> graphical.target" $?
[[ "$(readlink "$R/etc/systemd/system/display-manager.service")" == *sddm.service ]]; check "display-manager -> sddm.service" $?
[[ "$(readlink "$R/etc/systemd/system/systemd-networkd.service")" == /dev/null ]]; check "systemd-networkd masked" $?
[[ -L "$R/etc/systemd/system/multi-user.target.wants/NetworkManager.service" ]]; check "NetworkManager enabled" $?

echo "----- Phase 2: GPU drivers + profiles -----"
pkg nvidia-open-dkms;        check "NVIDIA: nvidia-open-dkms installed" $?
pkg nvidia-utils;            check "NVIDIA: nvidia-utils installed" $?
pkg lib32-nvidia-utils;      check "NVIDIA: lib32-nvidia-utils (multilib) installed" $?
pkg vulkan-radeon;           check "AMD: vulkan-radeon installed" $?
pkg lib32-vulkan-radeon;     check "AMD: lib32-vulkan-radeon installed" $?
pkg vulkan-intel;            check "Intel: vulkan-intel installed" $?
pkg mesa;                    check "Shared: mesa installed" $?
pkg lib32-mesa;              check "Shared: lib32-mesa installed" $?
pkg vulkan-icd-loader;       check "Shared: vulkan-icd-loader installed" $?
pkg linux-headers;           check "DKMS: linux-headers (mainline) installed" $?
pkg switcheroo-control;      check "Hybrid: switcheroo-control installed" $?
G="$R/usr/share/frag95/gpu"
[[ -f "$G/README.md" ]];                            check "GPU profiles shipped (README.md)" $?
[[ -x "$G/auto/detect.sh" ]];                       check "GPU auto-detect script present + executable" $?
[[ "$(cat "$G/nvidia/pkgs" 2>/dev/null)" == nvidia-open-dkms ]];        check "NVIDIA (open) profile -> nvidia-open-dkms" $?
[[ "$(cat "$G/nvidia-legacy/pkgs" 2>/dev/null)" == nvidia-470xx-dkms ]]; check "NVIDIA (legacy) profile -> nvidia-470xx-dkms" $?
[[ -f "$G/nouveau/modules" ]];                      check "nouveau (open-source) profile present" $?
[[ -f "$G/amd/modules" && -f "$G/intel/modules" && -f "$G/hybrid/modules" && -f "$G/vm/modules" ]]; check "amd/intel/hybrid/vm profiles present" $?

echo "----- Phase 2b: AUR out of the box -----"
pkg paru;   check "AUR: paru pre-installed" $?
pkg octopi; check "AUR: octopi pre-installed" $?
grep -q '^\[frag95\]'  "$R/etc/pacman.conf"; check "live /etc/pacman.conf has [frag95] repo" $?
grep -q '^\[multilib\]' "$R/etc/pacman.conf"; check "live /etc/pacman.conf has [multilib]" $?
[[ -e "$R/var/lib/frag95-repo/frag95.db" ]]; check "[frag95] repo db shipped on live image" $?
compgen -G "$R/var/lib/frag95-repo/paru-*.pkg.tar.*"   >/dev/null; check "[frag95] contains the paru package" $?
compgen -G "$R/var/lib/frag95-repo/octopi-*.pkg.tar.*" >/dev/null; check "[frag95] contains the octopi package" $?
compgen -G "$R/var/lib/frag95-repo/nvidia-470xx-utils-*.pkg.tar.*" >/dev/null; check "[frag95] contains nvidia-470xx-utils (legacy)" $?
compgen -G "$R/var/lib/frag95-repo/nvidia-470xx-dkms-*.pkg.tar.*"  >/dev/null; check "[frag95] contains nvidia-470xx-dkms (legacy)" $?

echo "----- Phase 3: gaming layer -----"
pkg steam;          check "Gaming: steam installed" $?
pkg gamemode;       check "Gaming: gamemode installed" $?
pkg lib32-gamemode; check "Gaming: lib32-gamemode installed" $?
pkg gamescope;      check "Gaming: gamescope installed" $?
pkg mangohud;       check "Gaming: mangohud installed" $?
pkg lib32-mangohud; check "Gaming: lib32-mangohud installed" $?
pkg goverlay;       check "Gaming: goverlay installed" $?
pkg vkbasalt;       check "Gaming: vkbasalt installed (from [frag95])" $?
pkg lib32-vkbasalt; check "Gaming: lib32-vkbasalt installed (from [frag95])" $?
compgen -G "$R/var/lib/frag95-repo/vkbasalt-*.pkg.tar.*"       >/dev/null; check "[frag95] contains vkbasalt" $?
compgen -G "$R/var/lib/frag95-repo/lib32-vkbasalt-*.pkg.tar.*" >/dev/null; check "[frag95] contains lib32-vkbasalt" $?

echo "----- Phase 4: old-PC-games layer -----"
pkg scummvm;        check "Retro: scummvm installed" $?
pkg wine-staging;   check "Retro: wine-staging installed" $?
pkg winetricks;     check "Retro: winetricks installed" $?
pkg lutris;         check "Retro: lutris installed" $?
pkg innoextract;    check "Retro: innoextract installed" $?
pkg cabextract;     check "Retro: cabextract installed" $?
pkg vkd3d;          check "Retro: vkd3d installed" $?
pkg dosbox-staging; check "Retro: dosbox-staging installed (from [frag95])" $?
pkg dxvk-bin;       check "Retro: dxvk-bin installed (from [frag95])" $?
pkg heroic-games-launcher-bin; check "Retro: heroic-games-launcher-bin installed (from [frag95])" $?
pkg bottles;        check "Retro: bottles installed (from [frag95])" $?
compgen -G "$R/var/lib/frag95-repo/dosbox-staging-*.pkg.tar.*" >/dev/null; check "[frag95] contains dosbox-staging" $?
compgen -G "$R/var/lib/frag95-repo/bottles-*.pkg.tar.*"        >/dev/null; check "[frag95] contains bottles" $?

echo "----- Phase 5: Windows 9x aesthetic (authentic Win95 theme) -----"
LNF="$R/usr/share/plasma/look-and-feel/org.frag95.redmond"
SK="$R/etc/skel/.config"
[[ -f "$R/usr/share/color-schemes/Win98.colors" ]];         check "Win98 color scheme shipped" $?
[[ -f "$R/usr/share/aurorae/themes/windows95-aurorae/metadata.desktop" ]]; check "windows95-aurorae decoration shipped" $?
[[ -f "$R/usr/share/plasma/desktoptheme/reactplus/metadata.desktop" ]]; check "reactplus plasma theme shipped" $?
[[ -d "$R/usr/share/icons/Chicago95_Standard_Cursors/cursors" || -f "$R/usr/share/icons/Chicago95_Standard_Cursors/index.theme" ]]; check "Chicago95 cursors shipped" $?
[[ -f "$R/usr/share/themes/Chicago95/index.theme" ]];       check "Chicago95 GTK theme shipped" $?
pkg chicago95-theme-git;                               check "Chicago95 icon theme installed (from [frag95])" $?
grep -q '^Inherits=.*breeze' "$R/usr/share/icons/Chicago95/index.theme" 2>/dev/null; check "Chicago95 inherits breeze (tray icons fall back, not blank)" $?
compgen -G "$R/var/lib/frag95-repo/chicago95-theme-git-*.pkg.tar.*" >/dev/null; check "[frag95] contains chicago95-icon-theme" $?
grep -q 'ColorScheme=Win98'  "$SK/kdeglobals" 2>/dev/null; check "skel kdeglobals -> Win98 colors" $?
grep -q 'widgetStyle=Windows' "$SK/kdeglobals" 2>/dev/null; check "skel kdeglobals -> Windows (3D) widget style" $?
grep -q 'Theme=Chicago95'    "$SK/kdeglobals" 2>/dev/null; check "skel kdeglobals -> Chicago95 icons" $?
grep -q 'windows95-aurorae'  "$SK/kwinrc" 2>/dev/null;     check "skel kwinrc -> windows95-aurorae decoration" $?
grep -q 'reactplus'          "$SK/plasmarc" 2>/dev/null;   check "skel plasmarc -> reactplus plasma theme" $?
grep -q 'Chicago95'          "$SK/gtk-3.0/settings.ini" 2>/dev/null; check "skel GTK -> Chicago95 (GTK apps)" $?
grep -q 'panel.floating = false' "$LNF/contents/layouts/org.kde.plasma.desktop-layout.js" 2>/dev/null; check "panel layout is non-floating" $?
grep -q 'org.kde.plasma.kicker' "$LNF/contents/layouts/org.kde.plasma.desktop-layout.js" 2>/dev/null; check "layout uses classic Start menu (kicker)" $?
grep -q 'ColorScheme=Win98'  "$LNF/contents/defaults" 2>/dev/null; check "look-and-feel defaults -> Win98 + Win95 components" $?
[[ -x "$R/usr/local/bin/frag95-firstrun.sh" ]];             check "first-run theme script present + executable" $?
[[ -f "$SK/autostart/frag95-firstrun.desktop" ]];          check "first-run autostart present in skel" $?
[[ -x "$R/usr/local/bin/frag95-restore-theme.sh" ]];       check "restore-theme script present + executable" $?
grep -q 'DefaultDarkLookAndFeel' "$R/usr/local/bin/frag95-restore-theme.sh" 2>/dev/null; check "restore-theme pins dark slot (Dark Mode stays in-theme)" $?
[[ -f "$R/usr/share/applications/frag95-restore-theme.desktop" ]]; check "Restore Frag95 Theme launcher shipped" $?
[[ -x "$R/usr/local/bin/frag95-gpu-mode.sh" ]];            check "GPU-mode GUI script present + executable" $?
grep -q 'TryExec=envycontrol' "$R/usr/share/applications/frag95-gpu-mode.desktop" 2>/dev/null; check "GPU-mode launcher hidden unless envycontrol present (hybrid only)" $?
[[ -f "$R/usr/share/frag95/gpu/hybrid/pkgs" ]] && grep -q envycontrol "$R/usr/share/frag95/gpu/hybrid/pkgs"; check "hybrid profile pulls in envycontrol" $?
[[ -f "$R/usr/share/sounds/frag95/index.theme" ]];        check "Win9x sound theme shipped" $?
[[ -f "$R/usr/share/sounds/frag95/stereo/desktop-login.oga" ]]; check "startup chime present in sound theme" $?
SNDN=$(ls "$R/usr/share/sounds/frag95/stereo/"*.oga 2>/dev/null | wc -l); [[ "$SNDN" -ge 10 ]]; check "sound theme has the full event set (>=10 sounds)" $?
[[ -x "$R/usr/local/bin/frag95-play-sound.sh" ]];          check "sound playback helper present + executable" $?
[[ -f "$SK/autostart/frag95-startup-sound.desktop" ]];     check "startup-sound autostart present in skel" $?
grep -q 'gtk-sound-theme-name=frag95' "$SK/gtk-3.0/settings.ini" 2>/dev/null; check "GTK sound theme -> frag95 (libcanberra/KDE pick it up)" $?
[[ -f "$R/usr/share/sddm/themes/frag95/Main.qml" ]];       check "Win9x SDDM greeter (Main.qml) shipped" $?
grep -q 'QtVersion=6' "$R/usr/share/sddm/themes/frag95/metadata.desktop" 2>/dev/null; check "SDDM greeter declares Qt6 (avoids Qt5 black-screen)" $?
! grep -qi 'SddmComponents' "$R/usr/share/sddm/themes/frag95/Main.qml" 2>/dev/null; check "SDDM greeter avoids Qt5-era SddmComponents" $?
grep -q '^Current=frag95' "$R/etc/sddm.conf.d/10-frag95.conf" 2>/dev/null; check "sddm.conf.d selects the frag95 greeter" $?
grep -q 'Current=frag95' "$R/etc/calamares/modules/shellprocess_cleanup.conf" 2>/dev/null; check "installer pins frag95 greeter in /etc/sddm.conf" $?
[[ -f "$LNF/contents/logout/Logout.qml" ]];                check "Win9x logout greeter (Logout.qml) shipped" $?
grep -q 'signal logoutRequested' "$LNF/contents/logout/Logout.qml" 2>/dev/null; check "logout greeter honors the greeter signal contract" $?
grep -q 'ksplashrc' "$R/usr/local/bin/frag95-restore-theme.sh" 2>/dev/null; check "restore script disables the KDE splash" $?

echo "----- Phase 6: Calamares installer -----"
pkg calamares;             check "Installer: calamares installed (from [frag95])" $?
pkg arch-install-scripts;  check "Installer: arch-install-scripts installed" $?
pkg grub;                  check "Installer: grub installed" $?
pkg efibootmgr;            check "Installer: efibootmgr installed" $?
CAL="$R/etc/calamares"
[[ -f "$CAL/settings.conf" ]];                       check "calamares settings.conf shipped" $?
[[ -f "$CAL/branding/frag95/branding.desc" ]];       check "calamares Frag95 branding shipped" $?
[[ -f "$CAL/modules/unpackfs.conf" ]];               check "calamares unpackfs config shipped" $?
[[ -f "$CAL/modules/bootloader.conf" ]];             check "calamares bootloader config shipped" $?
grep -q 'initcpio' "$CAL/settings.conf" 2>/dev/null && ! grep -q 'mkinitcpio' "$CAL/settings.conf"; check "sequence uses the initcpio module (not mkinitcpio)" $?
[[ -x "$R/usr/local/bin/frag95-apply-gpu.sh" ]];     check "GPU-apply script present + executable" $?
grep -q 'archiso.conf' "$CAL/modules/shellprocess_cleanup.conf" 2>/dev/null; check "inline cleanup de-archisos mkinitcpio" $?
grep -q 'vmlinuz-linux' "$CAL/modules/shellprocess_cleanup.conf" 2>/dev/null; check "inline cleanup restores the kernel to /boot" $?
grep -qE 'HOOKS=\(.*microcode' "$CAL/modules/shellprocess_cleanup.conf" 2>/dev/null; check "inline cleanup enables CPU microcode (bare-metal)" $?
grep -q 'vmlinuz-linux-lts' "$CAL/modules/shellprocess_cleanup.conf" 2>/dev/null; check "inline cleanup restores the linux-lts fallback kernel" $?
pkg intel-ucode; check "intel-ucode installed (microcode source)" $?
pkg linux-lts;   check "linux-lts fallback kernel installed" $?
[[ -f "$R/usr/share/applications/install-frag95.desktop" ]]; check "installer launcher shipped" $?
compgen -G "$R/var/lib/frag95-repo/calamares-*.pkg.tar.*" >/dev/null; check "[frag95] contains calamares" $?

echo "==================="
echo "PASS=$pass FAIL=$fail"
[[ "$fail" == "0" ]] && echo "ALL GOOD" || echo "SOME CHECKS FAILED"
