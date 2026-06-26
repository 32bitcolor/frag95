#!/usr/bin/env bash
#
# Build the bundled [frag95] package repo from the AUR. Each package is compiled
# with makepkg and dropped into iso/airootfs/var/lib/frag95-repo/, then indexed
# with repo-add. That directory ships on the ISO (so the live system has the
# repo) and is also exposed to pacstrap at build time (see assemble-iso.sh), so
# packages like paru/octopi can be installed into the image from [frag95].
#
# makepkg refuses to run as root, so this needs a non-root build user:
#   * In the builder container it runs as root and drops to the 'builder' user
#     (created in docker/Dockerfile.builder).
#   * On a native Arch host (build.sh --engine native) it runs as your user.
#
# Env:
#   REPO         repo root (default /repo, the container mount)
#   REFRESH_AUR  =1 rebuilds every package even if already cached in the repo
#
set -euo pipefail

REPO="${REPO:-/repo}"
REPODIR="$REPO/iso/airootfs/var/lib/frag95-repo"
DBNAME="frag95"
WORK="${AUR_WORK:-/tmp/frag95-aur}"
REFRESH="${REFRESH_AUR:-0}"

# Ordered AUR build list. These have no AUR dependencies, so a plain
# `makepkg -s` (which pulls official deps) is enough. The legacy NVIDIA 470xx
# stack uses --nodeps for the -dkms package (see below).
#   paru                AUR helper (CLI)         -> pre-installed on the live image
#   qt-sudo             octopi runtime dep (AUR)  -> pulled in as an octopi dependency
#   octopi              AUR/pacman GUI browser    -> pre-installed on the live image
#   envycontrol         hybrid-GPU switcher       -> installed by the Phase 6 hybrid profile
#   nvidia-470xx-utils  legacy NVIDIA userspace   -> installed by the nvidia-legacy profile
#   nvidia-470xx-dkms   legacy NVIDIA kmod source -> installed by the nvidia-legacy profile
#   vkbasalt            Vulkan post-processing     -> pre-installed (gaming overlay)
#   lib32-vkbasalt      32-bit vkbasalt            -> pre-installed (for 32-bit games)
# Phase 4 (old-PC-games): dosbox-staging needs iir1+munt; bottles pulls a flat
# chain of AUR deps. All deps are listed BEFORE their dependents so the
# incremental [frag95] indexing resolves each from the just-built repo:
#   iir1, munt                -> dosbox-staging deps
#   dosbox-staging            -> pre-installed (modern DOSBox fork)
#   dxvk-bin                  -> pre-installed (DXVK for Wine/Lutris)
#   heroic-games-launcher-bin -> pre-installed (Epic/GOG/Amazon launcher)
#   fvs2..python-pathvalidate -> bottles' AUR dependencies
#   bottles                   -> pre-installed (Wine prefix manager)
# (qt-sudo / nvidia-470xx-utils have only official deps. nvidia-470xx-dkms
#  depends on nvidia-470xx-utils, but only at *runtime* — packaging the DKMS
#  source needs nothing installed — so it's built with makepkg --nodeps and the
#  runtime dep is satisfied from [frag95] when the installer pulls it onto the
#  target. That avoids having to install one AUR package to build the next.)
PKGS=(
    paru qt-sudo octopi envycontrol
    nvidia-470xx-utils nvidia-470xx-dkms
    vkbasalt lib32-vkbasalt
    iir1 munt dosbox-staging dxvk-bin heroic-games-launcher-bin
    fvs2 python-fvs python-setuptools-reproducible patool
    python-steamgriddb vkbasalt-cli python-pathvalidate bottles
    ckbcomp calamares
    chicago95-theme-git
    msi-ec-dkms-git
)

IS_ROOT=0; [[ "${EUID:-$(id -u)}" -eq 0 ]] && IS_ROOT=1

# Run a bash snippet as the unprivileged build user (self if already non-root).
run_as() {
    if [[ "$IS_ROOT" -eq 1 ]]; then
        id builder &>/dev/null || { echo "!! Running as root but no 'builder' user exists." >&2; exit 1; }
        sudo -u builder --preserve-env=AUR_WORK bash -euo pipefail -c "$1"
    else
        bash -euo pipefail -c "$1"
    fi
}
# pacman as root (direct if root, else via sudo) — for the db refresh.
pac() { if [[ "$IS_ROOT" -eq 1 ]]; then pacman "$@"; else sudo pacman "$@"; fi; }

echo "==> Building [frag95] local repo at $REPODIR"
mkdir -p "$REPODIR" "$WORK"
[[ "$IS_ROOT" -eq 1 ]] && chown -R builder "$WORK"

# Drop any -debug split packages (makepkg emits them by default); they only
# bloat the repo + ISO and are never installed. Runs every time, so a stale
# debug pkg from an older build gets cleaned even when the real pkg is cached.
rm -f "$REPODIR"/*-debug-*.pkg.tar.* 2>/dev/null || true

# lib32-* AUR packages need [multilib] enabled in the BUILD environment so their
# lib32 build deps resolve. In the container (root) enable it if missing; on a
# native host we leave the host config alone (a gaming-distro builder will
# already have multilib on — build-localrepo errors clearly if a lib32 dep is
# unresolvable).
if [[ "$IS_ROOT" -eq 1 ]] && ! grep -q '^\[multilib\]' /etc/pacman.conf; then
    echo "==> Enabling [multilib] in the builder for lib32-* AUR builds"
    printf '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' >> /etc/pacman.conf
fi

# Expose the in-progress repo to the builder's pacman as [frag95], so a package
# that depends on another AUR package we just built (e.g. lib32-vkbasalt ->
# vkbasalt) can resolve it. Only when we control /etc/pacman.conf (container).
if [[ "$IS_ROOT" -eq 1 ]] && ! grep -q '^\[frag95\]' /etc/pacman.conf; then
    printf '\n[frag95]\nSigLevel = Optional TrustAll\nServer = file://%s\n' "$REPODIR" >> /etc/pacman.conf
fi

# (Re)index the db from whatever is already cached so those packages are
# resolvable as deps from the start; seed an empty db if the repo is fresh.
( cd "$REPODIR"
  rm -f "$DBNAME".db* "$DBNAME".files*
  if compgen -G '*.pkg.tar.*' >/dev/null; then
      repo-add "$DBNAME.db.tar.gz" ./*.pkg.tar.* >/dev/null
  else
      tar -czf "$DBNAME.db.tar.gz" -T /dev/null && ln -sf "$DBNAME.db.tar.gz" "$DBNAME.db"
  fi )

echo "==> Refreshing pacman databases (for makepkg dep resolution)"
pac -Sy --noconfirm >/dev/null

built=0; cached=0
for pkg in "${PKGS[@]}"; do
    if [[ "$REFRESH" != 1 ]] && compgen -G "$REPODIR/${pkg}-*.pkg.tar.*" >/dev/null; then
        echo "  [cached] $pkg"; cached=$((cached + 1)); continue
    fi
    # -dkms packages only bundle kernel-module source, so they don't need their
    # (AUR) runtime deps installed to build — use --nodeps. Everything else pulls
    # build deps (official, or AUR deps already in [frag95]) via --syncdeps.
    mkflags="--syncdeps --needed"
    case "$pkg" in *-dkms) mkflags="--nodeps" ;; esac
    echo "  [build]  $pkg (cloning + makepkg $mkflags from the AUR)"
    run_as "
        cd '$WORK'
        rm -rf '$pkg'
        git clone --depth 1 'https://aur.archlinux.org/${pkg}.git'
        cd '$pkg'
        makepkg $mkflags --noconfirm --clean
    "
    # Split PKGBUILDs (e.g. octopi) emit several package files — keep them all,
    # except the -debug symbol packages. Index each into the db immediately and
    # refresh, so the next package in the list can resolve it as a dependency.
    newfiles=()
    for f in "$WORK/$pkg"/*.pkg.tar.*; do
        case "$(basename "$f")" in *-debug-*) continue ;; esac
        cp "$f" "$REPODIR/"
        newfiles+=("$REPODIR/$(basename "$f")")
    done
    if [[ "${#newfiles[@]}" -gt 0 ]]; then
        repo-add "$REPODIR/$DBNAME.db.tar.gz" "${newfiles[@]}" >/dev/null
        pac -Sy --noconfirm >/dev/null
    fi
    built=$((built + 1))
done

[[ "$IS_ROOT" -eq 1 ]] && chown -R root:root "$REPODIR"
echo "==> [frag95] ready: built=$built cached=$cached, $(ls -1 "$REPODIR"/*.pkg.tar.* | wc -l | tr -d ' ') package file(s)"
