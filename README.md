# Frag95

A 90s-aesthetic, gaming-first Linux distribution built on Arch Linux.

> **Frag95** is a working codename. Rename later via `iso/profiledef.sh` + branding assets.

## What it is

- **Windows 9x desktop aesthetic** on KDE Plasma (gray 3D bevels, teal desktop, Start-menu panel, pixel fonts).
- **NVIDIA *and* AMD GPUs out of the box** — driver config chosen in the installer (Auto / NVIDIA / AMD / Hybrid / VM).
- **Gaming-first**: Steam pre-installed, Proton/gamemode/gamescope/MangoHud tuned.
- **Old PC games made easy**: DOSBox-Staging, ScummVM, Wine + Lutris/Bottles/Heroic, DXVK/Glide wrappers, CRT shaders.
- **Runs on all x86-64 PC hardware**; first-class GPU + sensor/thermal support across major gaming-laptop brands.
- **AUR working out of the box**: `paru` (CLI) + `octopi` (GUI browser) pre-installed.
- **Installable** via a themed Calamares installer; **installable in a VM** (QEMU/VirtualBox/VMware/Hyper-V).

See the full plan in `docs/PLAN.md` (mirror of the approved design).

## Building (on Windows, via Docker)

Requires Docker Desktop (WSL2 backend) running. The ISO is built inside a privileged
`archlinux` container running `mkarchiso` — no Arch install needed on the host.

```powershell
# Build the builder image (first time only) and produce the ISO:
.\build.ps1

# Output ISO lands in .\out\
```

Optional flags:

```powershell
.\build.ps1 -Rebuild   # force-rebuild the Docker builder image
.\build.ps1 -Test      # after building, run the QEMU boot smoke test
```

## How the build works

We don't hand-maintain a full archiso profile. Instead:

1. The build seeds the official `releng` profile from `/usr/share/archiso/configs/releng`
   (keeps all the live-boot essentials current with upstream).
2. It overlays our deltas from `iso/`:
   - `profiledef.sh`, `pacman.conf` replace the upstream ones.
   - `packages.add.x86_64` is **appended** to releng's package list (so live-boot packages stay).
   - `airootfs/` is **overlaid** on top of releng's airootfs (we only add files).
3. It enables our services (SDDM, NetworkManager, graphical target) via systemd symlinks.
4. It runs `mkarchiso` to produce the ISO.

See `scripts/build-in-container.sh`.

## Flashing to USB

Write `out/frag95-*.iso` to a USB stick with [Ventoy](https://www.ventoy.net/) (recommended)
or Rufus (DD mode). Boot in UEFI mode.

## Status

Phase 1: minimal bootable base + KDE Plasma + autologin live user. See `docs/PLAN.md` for the roadmap.
