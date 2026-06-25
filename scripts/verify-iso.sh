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
    etc/systemd/system usr/share/xsessions usr/share/frag95 >/dev/null 2>&1

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
grep -q 'User=frag' "$R/etc/sddm.conf.d/10-frag95.conf"; check "SDDM autologin user=frag" $?
grep -q 'Session=plasmax11' "$R/etc/sddm.conf.d/10-frag95.conf"; check "SDDM session=plasmax11 (X11 default)" $?
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

echo "==================="
echo "PASS=$pass FAIL=$fail"
[[ "$fail" == "0" ]] && echo "ALL GOOD" || echo "SOME CHECKS FAILED"
