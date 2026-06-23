#!/usr/bin/env bash
# shellcheck disable=SC2034
#
# Frag95 archiso profile definition (overrides releng's profiledef.sh).

iso_name="frag95"
iso_label="FRAG95_$(date +%Y%m)"
iso_publisher="Frag95 Project"
iso_application="Frag95 Live / Install"
iso_version="$(date +%Y.%m.%d)"
install_dir="frag95"
buildmodes=('iso')
bootmodes=(
    'bios.syslinux.mbr'
    'bios.syslinux.eltorito'
    'uefi-ia32.systemd-boot.esp'
    'uefi-x64.systemd-boot.esp'
    'uefi-ia32.systemd-boot.eltorito'
    'uefi-x64.systemd-boot.eltorito'
)
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '19' '-b' '1M')
bootstrap_tarball_compression=(
    'zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19'
)
file_permissions=(
    ["/etc/shadow"]="0:0:400"
    ["/root"]="0:0:750"
    ["/etc/sudoers.d/10-wheel-nopasswd"]="0:0:440"
    ["/usr/local/bin/"]="0:0:755"
)
