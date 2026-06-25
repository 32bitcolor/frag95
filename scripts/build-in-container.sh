#!/usr/bin/env bash
#
# Container entrypoint for the Frag95 ISO build. Runs inside the privileged
# frag95-builder container (see docker/Dockerfile.builder), launched by
# build.sh / build.ps1.
#
# Its only container-specific job is keeping the image's archiso/rsync current;
# the actual build is the OS-agnostic scripts/assemble-iso.sh (shared with the
# native, no-container build path).
#
set -euo pipefail

REPO="${REPO:-/repo}"

echo "==> Refreshing builder packages (archiso etc.)"
pacman -Syu --noconfirm --needed archiso rsync >/dev/null

echo "==> Building the bundled [frag95] AUR repo (paru/octopi/...)"
"$REPO/scripts/build-localrepo.sh"

exec "$REPO/scripts/assemble-iso.sh"
