# Download & Build Frag95

Two ways to get a Frag95 ISO:

- **[Option A — Download the prebuilt ISO](#option-a--download-the-prebuilt-iso)** (fastest; recommended for most people)
- **[Option B — Build it yourself from source](#option-b--build-it-yourself-from-source)** (any OS, no Arch install needed)

Then **[flash it to a USB stick](#flashing-to-a-usb-stick)** and boot.

---

## Option A — Download the prebuilt ISO

The official 1.0 ISO is hosted on the Internet Archive (it's ~4.1 GB, over
GitHub's 2 GB release-asset limit).

### 1. Download the ISO

- **Direct link:** <https://archive.org/download/frag95-1.0-x86_64/frag95-1.0-x86_64.iso>
- **Details page (with a torrent):** <https://archive.org/details/frag95-1.0-x86_64>
- Or from the [GitHub v1.0 release](https://github.com/32bitcolor/frag95/releases/tag/v1.0).

Command-line download:

```bash
curl -L -o frag95-1.0-x86_64.iso \
  https://archive.org/download/frag95-1.0-x86_64/frag95-1.0-x86_64.iso
```

### 2. Verify the download (recommended)

Confirm the file isn't corrupt or tampered with. The expected SHA-256 is:

```
e39c1097655d57044399173acffa70d25c821c9bfe2feee68e0ca47e4316b9e4
```

| OS | Command |
|----|---------|
| **Linux** | `sha256sum frag95-1.0-x86_64.iso` |
| **macOS** | `shasum -a 256 frag95-1.0-x86_64.iso` |
| **Windows** (PowerShell) | `Get-FileHash frag95-1.0-x86_64.iso -Algorithm SHA256` |

The output hash must match the value above exactly. If it doesn't, re-download.

Now skip to **[Flashing to a USB stick](#flashing-to-a-usb-stick)**.

---

## Option B — Build it yourself from source

Frag95 builds on **Linux, macOS, or Windows**. By default it builds inside a
privileged `archlinux` container, so **you do not need an Arch install** — just a
container runtime. The finished ISO lands in `out/`.

### 1. Install prerequisites

You need **git** and a **container runtime** (Docker or Podman):

| OS | What to install |
|----|-----------------|
| **Linux** | `git` + Docker (or Podman) from your package manager. Start the daemon (`sudo systemctl start docker`) and make sure your user can run containers (add yourself to the `docker` group, or run with `sudo`). |
| **macOS** | `git` (via Xcode Command Line Tools or Homebrew) + [Docker Desktop](https://www.docker.com/products/docker-desktop/) (or Podman/Colima). Launch Docker Desktop so the daemon is running. |
| **Windows** | [Docker Desktop](https://www.docker.com/products/docker-desktop/) with the **WSL2 backend** + git. Build from PowerShell (`build.ps1`) or from a WSL/Git Bash shell (`build.sh`). |

You also need:

- **~20 GB free disk space** (the ISO is ~4.1 GB; the build also caches packages
  and uses a scratch work directory).
- A reliable **internet connection** — the build downloads Arch packages and
  compiles several AUR packages from source.
- Docker must be allowed to run **privileged** containers (the default on Docker
  Desktop and standard Docker installs).

### 2. Get the source

```bash
git clone https://github.com/32bitcolor/frag95.git
cd frag95
```

### 3. Build the ISO

**Linux / macOS / WSL / Git Bash:**

```bash
./build.sh
```

**Native Windows PowerShell:**

```powershell
.\build.ps1
```

That's the whole build. On the **first** run it will:

1. Build the `frag95-builder` container image.
2. Compile the bundled `[frag95]` AUR packages (paru, octopi, gaming/legacy
   libraries, the installer, etc.) — this is the slow part.
3. Run `mkarchiso` to assemble and compress the ISO.

Expect **roughly 30–60+ minutes** the first time (less on later builds — the
package cache and AUR repo are reused via a persistent Docker volume).

Useful flags:

```bash
./build.sh --rebuild        # force-rebuild the builder container image
./build.sh --test           # after building, run a QEMU boot smoke test
./build.sh --engine native  # build with the host's mkarchiso (Arch hosts only)
./build.sh --help
```

> **Building a versioned/release ISO:** set `FRAG95_VERSION` to name the output
> (e.g. `FRAG95_VERSION=1.0 ./build.sh` → `out/frag95-1.0-x86_64.iso`). Without
> it, the ISO is named with the build date.

### 4. Find your ISO

```
out/frag95-<version>-x86_64.iso
```

### 5. Verify the build (optional)

A correct-by-construction check confirms all the customizations landed in the
image. Run it inside the builder container:

```bash
docker run --rm --privileged \
  -v "$PWD:/repo" -v "$PWD/out:/out" -e OUT=/out \
  frag95-builder -c 'bash /repo/scripts/verify-iso.sh'
```

It picks the newest ISO in `out/` and should end with `ALL GOOD`.

---

## Flashing to a USB stick

Write the ISO to a USB drive (this **erases** the drive):

- **[Ventoy](https://www.ventoy.net/)** (recommended) — install Ventoy on the
  USB once, then just copy the `.iso` onto it. Lets you keep multiple ISOs.
- **[balenaEtcher](https://etcher.balena.io/)** — cross-platform, point-and-click.
- **Rufus** (Windows) — use **DD mode** when prompted.
- **`dd`** (Linux/macOS, advanced) — double-check the device path first:

  ```bash
  sudo dd if=frag95-1.0-x86_64.iso of=/dev/sdX bs=4M status=progress oflag=sync
  ```

  Replace `/dev/sdX` with your USB device (e.g. `/dev/sdb`). **Writing to the
  wrong device will destroy its data.**

## Booting

1. Boot the PC from the USB stick (use the firmware boot menu — often **F12**,
   **F11**, **F8**, or **Esc** at power-on).
2. **Disable Secure Boot** in firmware — Frag95's bootloader is unsigned.
3. Boot in **UEFI mode** (BIOS/legacy also works, but UEFI is preferred).

You land in the live Frag95 desktop. To install to disk, launch the **Calamares
installer** from the desktop/Start menu.
