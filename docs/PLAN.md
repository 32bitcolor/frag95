# Plan: "Frag95" — a 90s-aesthetic, gaming-first Arch-based Linux distro

> "Frag95" is a working codename — trivially renamed later (one variable in `profiledef.sh` + branding assets). Pick a real name whenever you like.

## Context

A custom Linux distribution built on Arch Linux that:
- Has a **Windows 9x desktop aesthetic** (gray 3D bevels, teal desktop, Start-menu panel, pixel fonts) on **KDE Plasma**.
- Works with **both NVIDIA and AMD GPUs out of the box** — no manual driver install. The **install wizard lets the user pick their GPU** (Auto-detect / NVIDIA / AMD / Hybrid / VM-generic), and the right driver config is applied accordingly.
- Is **gaming-first**: smooth on laptops, **Steam pre-installed**, Proton/overlays/tuning ready to go.
- Makes **old PC games easy to run** — DOS/Win9x/XP-era titles, GOG installers, Glide/early-Direct3D games — with launchers and wrappers pre-configured (pairs with the 90s aesthetic via CRT shaders + integer scaling).
- Is **installable in a virtual machine** (QEMU/KVM, VirtualBox, VMware, Hyper-V) — guest tools included; the same ISO boots cleanly whether or not an NVIDIA GPU is present.
- **Runs on all PC hardware across the board** — a general-purpose Arch system with full `linux-firmware` and a generic, hardware-agnostic live image boots on any x86-64 machine. No machine is hard-coded.
- Gives a **first-class experience on all major gaming-laptop brands** (MSI, Alienware/Dell, ASUS ROG, Lenovo Legion, Razer, Acer, Gigabyte/Aorus, HP Omen): perfect GPU utilization (hybrid/dGPU correctly used) and **sensors + temperature/fan management working out of the box**. Brand tools applied via detected vendor profiles.
- **Reference test machines:** MSI Stealth 15M A11UEK-021US (i7-11375H, RTX 3060 Laptop/Ampere, AX201, Iris Xe → Optimus) and Alienware m18 R1 (Intel 13th-gen HX *or* Ryzen 7045HX, RTX 40-series/Ada, Killer Wi-Fi, MUX switch; Cirrus CS35L41 speaker amps are the known Linux audio gotcha).
- Is **installable to disk** via a themed **Calamares** installer.
- Defaults to the **X11 Plasma session** (most compatible for Steam/Proton/overlays on NVIDIA); Wayland selectable.
- **AUR works 100% out of the box** — `paru` (CLI) + `octopi` (GUI browser) pre-installed via a bundled local repo.

Build host: **Docker Desktop (WSL2)** — ISO built in a privileged `archlinux` container running `mkarchiso`.

### Key technical findings
- Arch ships **`nvidia-open`** as default for Turing+ → use **`nvidia-open-dkms`** (rebuilds across `linux`/`linux-lts`).
- Plasma Wayland + NVIDIA needs driver ≥555 (explicit sync, Plasma 6.1+).
- Ampere laptop gotcha (MSI Stealth): GSP firmware bugs → fallback `nvidia.NVreg_EnableGpuFirmware=0`.
- Hybrid/Optimus → PRIME render offload + `switcheroo-control` + `envycontrol`.

## How the build is structured

We don't fork the whole releng profile into git. The build (`scripts/build-in-container.sh`) seeds
the upstream `releng` profile, then overlays our deltas from `iso/`:
- `profiledef.sh` + `pacman.conf` replace upstream.
- `packages.add.x86_64` is **appended** to releng's package list.
- `airootfs/` is **overlaid** additively.
- Services (SDDM, NetworkManager, graphical target) enabled via systemd symlinks in the build script.
- AUR helper + GUI browser are prebuilt into a `[frag95]` local repo (`scripts/build-localrepo.sh`, Phase 2+).

## Package set (by concern)

- **Base/boot:** `base base-devel linux linux-headers linux-lts linux-lts-headers linux-firmware mkinitcpio intel-ucode amd-ucode`.
- **NVIDIA:** `nvidia-open-dkms nvidia-utils lib32-nvidia-utils nvidia-settings opencl-nvidia egl-wayland libva-nvidia-driver`.
- **AMD:** in-kernel `amdgpu` + `vulkan-radeon lib32-vulkan-radeon libva-mesa-driver mesa-vdpau`.
- **Shared Mesa/Intel:** `mesa lib32-mesa vulkan-icd-loader lib32-vulkan-icd-loader vulkan-mesa-layers vulkan-intel lib32-vulkan-intel intel-media-driver`.
- **Hybrid:** `switcheroo-control` + `envycontrol`.
- **KDE Plasma:** `plasma-meta sddm konsole dolphin kate ark spectacle kscreen plasma-pa plasma-nm xorg-server xorg-xinit`.
- **Gaming:** `steam gamemode lib32-gamemode gamescope mangohud lib32-mangohud goverlay vkbasalt lib32-vkbasalt wine winetricks lutris ttf-liberation`.
- **Old PC games:** `dosbox-staging scummvm wine-staging innoextract cabextract` + Flatpak Bottles/Heroic; DXVK/d8vk/wined3d; openglide.
- **VM guest tools:** `qemu-guest-agent spice-vdagent open-vm-tools virtualbox-guest-utils hyperv` (enabled per `systemd-detect-virt`).
- **Audio:** `pipewire pipewire-pulse pipewire-alsa lib32-pipewire wireplumber sof-firmware`.
- **Net/system:** `networkmanager bluez bluez-utils power-profiles-daemon thermald flatpak`.
- **Sensors/thermal:** `lm_sensors fancontrol` + Plasma temp widgets; `sensors-detect --auto` on first boot.
- **Vendor tools (per brand, from AUR):** `openrgb nbfc-linux`; ASUS `asusctl supergfxctl`; Lenovo `lenovo-legion-linux`.
- **Installer:** `calamares arch-install-scripts`.
- **AUR:** `base-devel git` + prebuilt `paru` + `octopi`; `[multilib]` + `[frag95]` repos enabled.

## GPU support (NVIDIA + AMD, installer-chosen)

Live ISO ships every driver and boots vendor-agnostic. The installer GPU page (Auto/NVIDIA/AMD/Hybrid/VM)
writes the matching `mkinitcpio.conf` MODULES, `modprobe.d`, and kernel params, then regenerates initramfs once.
- **NVIDIA:** early-KMS modules, `nvidia_drm modeset=1 fbdev=1`, Ampere GSP fallback, initramfs pacman hook.
- **AMD:** `amdgpu` early KMS; no proprietary modules.
- **Hybrid:** PRIME offload + "Run with dedicated GPU" Plasma service menu.
- **VM/generic:** virtio/modesetting + Mesa; enable matching guest agent.
- X11 default session regardless of GPU; Wayland selectable.

## AUR out of the box
- `paru` prebuilt into `[frag95]`; `octopi` GUI browser pinned in the Start menu (Discover handles repos + Flatpak).
- `base-devel`, `git`, sudo-enabled user → `makepkg`/AUR works immediately.
- Vendor tools delivered via `paru -S` from detected profiles.

## Windows 9x aesthetic
Plasma global theme (redmond decoration, gray 3D-bevel color scheme, classic Kicker Start menu, square corners,
no blur/animations), MS-Sans-Serif-alike + pixel fonts, classic cursors/icons, teal/branded wallpaper, themed SDDM.
Applied via skel `~/.config` + baked into Calamares.

## Hardware support
Universal base (full firmware, mainline+LTS kernels, all GPU stacks) runs anywhere. Cross-brand guarantees:
correct hybrid/dGPU usage, `thermald` + `power-profiles-daemon`, `lm_sensors` auto-detected, Plasma temp widgets.
Data-driven vendor profiles applied by DMI detection; VMs detected via `systemd-detect-virt`.

## Phasing
1. **Scaffold + minimal bootable ISO** — base + Plasma + SDDM + autologin live user. *(this phase)*
2. **GPU out-of-box (NVIDIA + AMD) & AUR** — drivers + early-KMS profiles + PRIME/hybrid + multilib + local repo (paru/octopi).
3. **Gaming layer** — Steam + gamemode/gamescope/mangohud/vkbasalt + Proton deps.
4. **Old-PC-games layer** — DOSBox/ScummVM/Wine-staging + Lutris + Flatpak Bottles/Heroic + DXVK/Glide + CRT presets.
5. **Windows 9x aesthetic** — global theme, fonts, cursors, wallpaper, SDDM theme, boot branding.
6. **Calamares installer** — themed installer + GPU-choice page; primary test loop = install into QEMU.
7. **Hardware tuning + polish** — sensors/thermal + GPU utilization across brands, vendor profiles, real-hardware validation, release automation, docs.

## Verification
- Build asserts manifest contains `steam`, `nvidia-open-dkms`, `vulkan-radeon`, `plasma-meta`, `calamares`, `paru`, `octopi`, `lm_sensors`.
- AUR end-to-end in VM (octopi GUI + `paru -S`); `sensors` returns temps.
- `scripts/qemu-test.sh` boot smoke test each phase.
- Full Calamares-into-QEMU install as the primary dev loop.
- **Honest limitation:** NVIDIA dGPU, hybrid switching, Wi-Fi, Cirrus amps, real gaming perf require real hardware (USB boot). The VM proves everything else.
