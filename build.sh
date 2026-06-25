#!/usr/bin/env bash
#
# Frag95 ISO build entrypoint — works on any OS.
#
#   ./build.sh                    # build the ISO (auto-pick an engine)
#   ./build.sh --rebuild          # force a rebuild of the container builder image
#   ./build.sh --test             # boot smoke-test the ISO after building
#   ./build.sh --engine native    # build directly with the host's mkarchiso
#   ./build.sh --engine docker    # force the containerized build
#   ./build.sh -h | --help
#
# Engines
#   container  Universal. Builds inside a privileged archlinux container, so no
#              Arch host is needed — works on Linux, macOS, and Windows (via WSL
#              or Git Bash). Uses docker, or podman if docker is absent.
#   native     Fastest, no container, but requires an Arch-based host with the
#              'archiso' package installed. Runs mkarchiso under sudo.
#
# Auto mode picks 'native' when mkarchiso is on PATH, otherwise 'container'.
#
set -euo pipefail

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="frag95-builder"

ENGINE="auto"
REBUILD=0
TEST=0

usage() { sed -n '2,/^set -euo/p' "$0" | sed 's/^#\{0,1\} \{0,1\}//; /^set -euo/d'; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --engine) ENGINE="${2:-}"; shift 2 ;;
        --native) ENGINE="native"; shift ;;
        --docker|--container) ENGINE="container"; shift ;;
        --rebuild) REBUILD=1; shift ;;
        --test) TEST=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "!! Unknown option: $1" >&2; usage; exit 2 ;;
    esac
done

# --- Resolve the engine ------------------------------------------------------
detect_runtime() {
    local r
    for r in docker podman; do
        if command -v "$r" >/dev/null 2>&1; then echo "$r"; return 0; fi
    done
    return 1
}

if [[ "$ENGINE" == "auto" ]]; then
    if command -v mkarchiso >/dev/null 2>&1; then
        ENGINE="native"
    elif detect_runtime >/dev/null; then
        ENGINE="container"
    else
        echo "!! No build engine available." >&2
        echo "   Install EITHER 'archiso' (for --engine native, Arch hosts) OR" >&2
        echo "   docker/podman (for the universal containerized build)." >&2
        exit 1
    fi
fi

mkdir -p "$REPO/out"

# --- Native build (Arch host, no container) ----------------------------------
build_native() {
    if ! command -v mkarchiso >/dev/null 2>&1; then
        echo "!! --engine native needs the 'archiso' package (mkarchiso not found)." >&2
        echo "   On Arch: sudo pacman -S archiso rsync. Or use --engine container." >&2
        exit 1
    fi
    local sudo="" work="${TMPDIR:-/tmp}/frag95-work"
    [[ "$(id -u)" -ne 0 ]] && sudo="sudo"
    echo "==> Native build with host mkarchiso (work dir: $work)"
    $sudo env REPO="$REPO" WORK="$work" OUT="$REPO/out" "$REPO/scripts/assemble-iso.sh"
    # mkarchiso ran as root; hand the outputs back to the invoking user.
    [[ -n "$sudo" ]] && $sudo chown "$(id -u):$(id -g)" "$REPO"/out/*.iso 2>/dev/null || true
}

# --- Containerized build (universal) -----------------------------------------
build_container() {
    local rt
    rt="$(detect_runtime)" || {
        echo "!! No container runtime found (need docker or podman)." >&2
        exit 1
    }
    echo "==> Container engine: $rt"

    if [[ "$REBUILD" -eq 1 ]] || ! "$rt" image inspect "$IMAGE" >/dev/null 2>&1; then
        echo "==> Building builder image '$IMAGE'..."
        "$rt" build -t "$IMAGE" -f "$REPO/docker/Dockerfile.builder" "$REPO/docker"
    else
        echo "==> Reusing existing '$IMAGE' image (use --rebuild to refresh)."
    fi

    echo "==> Running mkarchiso (privileged $rt container)..."
    # Named volume persists pacman's package cache across builds (~1.8GB).
    "$rt" run --rm --privileged \
        -v "$REPO:/repo" \
        -v "$REPO/out:/out" \
        -v "frag95-pacman-cache:/var/cache/pacman/pkg" \
        -e REPO=/repo -e WORK=/work -e OUT=/out \
        "$IMAGE" /repo/scripts/build-in-container.sh
}

case "$ENGINE" in
    native)    build_native ;;
    container) build_container ;;
    *) echo "!! Invalid engine: '$ENGINE' (use native|container|auto)." >&2; exit 2 ;;
esac

echo "==> Build complete. ISO(s) in $REPO/out:"
ls -lh "$REPO"/out/*.iso 2>/dev/null || echo "   (no ISO found — check the log above)"

# --- Optional boot smoke test ------------------------------------------------
if [[ "$TEST" -eq 1 ]]; then
    echo "==> Running QEMU boot smoke test..."
    if [[ "$ENGINE" == "native" ]] && command -v qemu-system-x86_64 >/dev/null 2>&1; then
        OUT="$REPO/out" "$REPO/scripts/qemu-test.sh"
    else
        rt="$(detect_runtime)"
        "$rt" run --rm --privileged \
            -v "$REPO:/repo" -v "$REPO/out:/out" -e OUT=/out \
            "$IMAGE" /repo/scripts/qemu-test.sh
    fi
fi
