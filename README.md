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

## Building (any OS)

The ISO builds on **Linux, macOS, or Windows**. By default it builds inside a
privileged `archlinux` container running `mkarchiso`, so **no Arch install is
needed on the host** — you only need a container runtime (Docker or Podman).
Output ISO lands in `out/`.

```bash
# Linux / macOS / WSL / Git Bash:
./build.sh                 # build the ISO (auto-picks an engine)
./build.sh --rebuild       # force-rebuild the container builder image
./build.sh --test          # after building, run the QEMU boot smoke test
./build.sh --engine native # build directly with the host's mkarchiso (Arch only)
./build.sh --help
```

```powershell
# Native Windows PowerShell (equivalent wrapper, Docker Desktop with WSL2):
.\build.ps1
.\build.ps1 -Rebuild
.\build.ps1 -Test
```

**Engines.** `build.sh` auto-selects:

- **container** (default, universal) — builds in a privileged Docker/Podman
  `archlinux` container. Works anywhere a container runtime runs. On macOS and
  Windows this is the VM-backed Docker Desktop / Podman machine.
- **native** (`--engine native`) — no container; runs `mkarchiso` under `sudo`
  directly on an **Arch-based host** that has the `archiso` package. Fastest,
  and the right choice if you're already on Arch.

Both engines run the same OS-agnostic core (`scripts/assemble-iso.sh`) and
produce identical ISOs.

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

See `scripts/assemble-iso.sh` (the OS-agnostic build core; `scripts/build-in-container.sh`
is the thin container wrapper around it).

## Flashing to USB

Write `out/frag95-*.iso` to a USB stick with [Ventoy](https://www.ventoy.net/) (recommended)
or Rufus (DD mode). Boot in UEFI mode.

## Status

Phase 1: minimal bootable base + KDE Plasma + autologin live user. See `docs/PLAN.md` for the roadmap.
