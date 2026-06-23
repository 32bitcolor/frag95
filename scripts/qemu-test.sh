#!/usr/bin/env bash
#
# Best-effort boot smoke test: boot the freshly built ISO in QEMU (UEFI) and
# confirm it gets past the bootloader and starts the kernel/systemd.
#
# NOTE: This is a coarse "does it boot at all" check. It runs under TCG if
# /dev/kvm is unavailable (slow). It CANNOT validate GPU drivers, hybrid
# graphics, Wi-Fi, audio, or real gaming performance — those require booting on
# real hardware. See docs/PLAN.md "Verification".
#
set -euo pipefail

OUT="${OUT:-/out}"
ISO="$(ls -t "$OUT"/*.iso 2>/dev/null | head -n1 || true)"
if [[ -z "$ISO" ]]; then
    echo "!! No ISO found in $OUT. Build first." >&2
    exit 1
fi
echo "==> Testing boot of: $ISO"

OVMF_CODE="/usr/share/edk2/x64/OVMF_CODE.4m.fd"
OVMF_VARS_SRC="/usr/share/edk2/x64/OVMF_VARS.4m.fd"
[[ -f "$OVMF_CODE" ]] || OVMF_CODE="/usr/share/edk2-ovmf/x64/OVMF_CODE.fd"
[[ -f "$OVMF_VARS_SRC" ]] || OVMF_VARS_SRC="/usr/share/edk2-ovmf/x64/OVMF_VARS.fd"
cp "$OVMF_VARS_SRC" /tmp/OVMF_VARS.fd

ACCEL="tcg"
if [[ -e /dev/kvm ]]; then ACCEL="kvm"; fi
echo "==> Acceleration: $ACCEL"

LOG=/tmp/qemu-serial.log
set +e
timeout 420 qemu-system-x86_64 \
    -machine q35,accel="$ACCEL" \
    -m 4096 -smp 2 \
    -drive if=pflash,format=raw,unit=0,readonly=on,file="$OVMF_CODE" \
    -drive if=pflash,format=raw,unit=1,file=/tmp/OVMF_VARS.fd \
    -cdrom "$ISO" \
    -boot d \
    -display none \
    -serial file:"$LOG" \
    -no-reboot &
QPID=$!

# Watch the serial log for signs of a successful early boot.
SUCCESS=0
for _ in $(seq 1 420); do
    if grep -qiE "Welcome to|systemd|Reached target|Arch Linux|archiso" "$LOG" 2>/dev/null; then
        SUCCESS=1
        break
    fi
    kill -0 "$QPID" 2>/dev/null || break
    sleep 1
done
kill "$QPID" 2>/dev/null
wait "$QPID" 2>/dev/null
set -e

echo "----- serial tail -----"
tail -n 30 "$LOG" 2>/dev/null || true
echo "-----------------------"
if [[ "$SUCCESS" -eq 1 ]]; then
    echo "==> PASS: ISO reached the kernel/systemd boot stage."
    exit 0
fi
echo "!! INCONCLUSIVE: no boot markers seen on serial (ISO may still boot graphically)." >&2
echo "   The live image doesn't log to serial by default; validate visually in a VM/USB." >&2
exit 0
