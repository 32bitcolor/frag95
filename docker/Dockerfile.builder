# Frag95 ISO builder image.
# Provides archiso/mkarchiso plus the makepkg toolchain (for building AUR
# packages into our local repo) and QEMU (for the boot smoke test).
FROM archlinux:latest

RUN pacman -Syu --noconfirm --needed \
        archiso \
        git \
        base-devel \
        sudo \
        openssl \
        rsync \
        qemu-system-x86 \
        edk2-ovmf \
    && pacman -Scc --noconfirm

# Unprivileged user for makepkg (makepkg refuses to run as root).
RUN useradd -m -G wheel builder \
    && echo 'builder ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/builder \
    && chmod 0440 /etc/sudoers.d/builder

WORKDIR /repo
ENTRYPOINT ["/bin/bash"]
