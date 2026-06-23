#!/usr/bin/env bash
#
# Correct-by-construction check of a built Frag95 ISO: extract the rootfs
# squashfs and confirm our Phase 1 customizations actually landed.
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
    etc/systemd/system usr/share/xsessions >/dev/null 2>&1

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

echo "==================="
echo "PASS=$pass FAIL=$fail"
[[ "$fail" == "0" ]] && echo "ALL GOOD" || echo "SOME CHECKS FAILED"
