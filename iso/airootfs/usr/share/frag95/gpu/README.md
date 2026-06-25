# Frag95 GPU profiles

The live ISO ships **every** GPU driver stack (NVIDIA proprietary `nvidia-open-dkms`,
AMD/Intel Mesa, Vulkan + lib32 for all) so it boots on any machine. The live image
itself stays **vendor-agnostic**: it boots on the open/modesetting drivers
(`nouveau` / `amdgpu` / `i915` / virtio), and the proprietary NVIDIA module is
present but **not** force-loaded. This is what makes the same ISO boot cleanly in a
VM and on AMD as well as NVIDIA hardware.

The per-GPU early-KMS configuration lives here as plain data. The **Phase 6
Calamares installer** reads the profile the user picks on the GPU page
(Auto / NVIDIA / AMD / Hybrid / VM) and applies it to the **installed** system,
then regenerates the initramfs once. Nothing here is applied to the live image.

## How a profile is applied (Phase 6 installer contract)

For the selected profile directory `<p>/`:

1. `modules`      → space/newline-separated kernel modules to add to
                    `MODULES=(...)` in the target's `/etc/mkinitcpio.conf`
                    (early KMS).
2. `modprobe.conf`→ if present, install verbatim as
                    `/etc/modprobe.d/frag95-gpu.conf` on the target.
3. `cmdline`      → if non-empty, append these kernel parameters to the target
                    bootloader entry / cmdline.
4. `cmdline.*`    → conditional extra params (e.g. `cmdline.ampere` for the
                    Ampere GSP-firmware workaround) applied when the matching
                    hardware condition is detected.
5. Run `mkinitcpio -P` (or the bootloader's regen hook) **once** at the end.

`pkgs` (optional, per profile) lists the **kernel-module driver package** the
installer should ensure is installed on the target for that choice. The live ISO
ships `nvidia-open-dkms`; for the legacy/nouveau choices the installer swaps in
(or removes) the package named here. `nvidia-470xx-dkms` comes from the bundled
`[frag95]` repo (built from the AUR — Phase 2b), so the swap works offline.

## NVIDIA flavors (three install choices)

> `nvidia-open-dkms` **is** the proprietary NVIDIA driver. Only the *kernel
> module* is open-source; the driver itself (`nvidia-utils`: libGL, CUDA,
> NVENC/NVDEC, GSP firmware) is closed. It is NVIDIA's default and the only
> flavor in the current Arch repos. This is **not** nouveau.

- **nvidia/**        — proprietary, open-kernel-module flavor. **Turing and newer**
                       (GTX 16xx, RTX 20/30/40/50). `pkgs: nvidia-open-dkms`.
- **nvidia-legacy/** — proprietary legacy branch for **pre-Turing** cards (Pascal
                       GTX 10xx, Maxwell GTX 9xx). `pkgs: nvidia-470xx-dkms` (AUR,
                       via the `[frag95]` repo).
- **nouveau/**       — open-source community driver (no proprietary blob). Fallback
                       for any NVIDIA card; already in `mesa`/kernel.

## Profiles

- **auto/**         — detect at install time via `lspci`/`systemd-detect-virt`
                      and fall through to one of the profiles below. Installer default.
- **nvidia/**       — see "NVIDIA flavors" above. `cmdline.ampere` adds the GSP
                      firmware fallback for buggy Ampere laptops (e.g. MSI Stealth 15M).
- **nvidia-legacy/**— see "NVIDIA flavors" above.
- **nouveau/**      — see "NVIDIA flavors" above.
- **amd/**          — AMD `amdgpu` (in-kernel). Early KMS only; no proprietary modules.
- **intel/**        — Intel `i915` (in-kernel) iGPU. Early KMS; `intel-media-driver` VA-API.
- **hybrid/**       — Intel/AMD iGPU + NVIDIA dGPU (Optimus). NVIDIA modeset on, PRIME
                      render offload; pairs with `switcheroo-control` + `envycontrol`.
- **vm/**           — virtual machines. virtio/QXL/VMware/VirtualBox KMS + Mesa; the
                      installer also enables the matching guest agent.
