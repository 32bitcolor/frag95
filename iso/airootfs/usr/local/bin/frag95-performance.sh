#!/usr/bin/env bash
#
# Frag95 performance/cooling profiles.
#
# Tunes the laptop between quiet-and-cool-running and loud-and-fast by setting
# (on MSI laptops, via the msi-ec driver) the EC fan mode, shift/performance
# mode and Cooler Boost, plus the power-profiles-daemon profile. On non-MSI or
# unsupported hardware it just sets the power profile (the MSI bits are skipped
# gracefully), so it's safe to ship everywhere.
#
#   frag95-performance.sh {silent|balanced|performance|extreme|status|restore}
#
# Profiles:
#   silent       quietest: silent fan curve, eco shift, power-saver
#   balanced     default:  auto fan curve, comfort shift, balanced
#   performance  fast:     advanced fan curve, turbo shift, performance
#   extreme      max:      advanced fans + Cooler Boost (max RPM), turbo, performance
#
set -uo pipefail

MSI=/sys/devices/platform/msi-ec
STATE=/var/lib/frag95/performance-profile

usage() { echo "usage: ${0##*/} {silent|balanced|performance|extreme|status|restore}"; }

# write to an msi-ec attribute only if the driver exposes it (writable)
set_ec() { [ -w "$MSI/$1" ] && printf '%s' "$2" > "$MSI/$1" 2>/dev/null || true; }

set_ppd() { command -v powerprofilesctl >/dev/null 2>&1 && powerprofilesctl set "$1" 2>/dev/null || true; }

apply() {
    local fan shift boost ppd
    case "$1" in
        silent)      fan=silent;   shift=eco;     boost=off; ppd=power-saver ;;
        balanced)    fan=auto;     shift=comfort; boost=off; ppd=balanced ;;
        performance) fan=advanced; shift=turbo;   boost=off; ppd=performance ;;
        extreme)     fan=advanced; shift=turbo;   boost=on;  ppd=performance ;;
        *) usage; return 2 ;;
    esac

    if [ -d "$MSI" ]; then
        # shift_mode first (it can reset the fan mode on some firmwares), then fan, then boost
        set_ec shift_mode "$shift"
        set_ec fan_mode "$fan"
        set_ec cooler_boost "$boost"
    fi
    set_ppd "$ppd"

    mkdir -p "$(dirname "$STATE")"; printf '%s\n' "$1" > "$STATE" 2>/dev/null || true
    printf 'Frag95 performance profile: %s\n' "$1"
    [ -d "$MSI" ] || printf '  (no MSI EC on this machine -- set power profile only)\n'
}

status() {
    printf 'saved profile: %s\n' "$(cat "$STATE" 2>/dev/null || echo balanced)"
    if [ -d "$MSI" ]; then
        printf '  fan_mode=%s shift_mode=%s cooler_boost=%s\n' \
            "$(cat "$MSI/fan_mode" 2>/dev/null)" \
            "$(cat "$MSI/shift_mode" 2>/dev/null)" \
            "$(cat "$MSI/cooler_boost" 2>/dev/null)"
        printf '  CPU %sC / GPU %sC\n' \
            "$(cat "$MSI/cpu/realtime_temperature" 2>/dev/null)" \
            "$(cat "$MSI/gpu/realtime_temperature" 2>/dev/null)"
    fi
    command -v powerprofilesctl >/dev/null 2>&1 && printf '  power profile: %s\n' "$(powerprofilesctl get 2>/dev/null)"
}

case "${1:-status}" in
    silent|balanced|performance|extreme) apply "$1" ;;
    status)  status ;;
    restore) apply "$(cat "$STATE" 2>/dev/null || echo balanced)" ;;  # re-apply saved (used at boot)
    *)       usage; exit 2 ;;
esac
