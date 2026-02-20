#!/usr/bin/env bash
set -e

#Bootstrap the system
# $1: Architecture (amd64, arm64, armhf)
# $2: Target directory

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: $0 <architecture> <directory>"
  exit 1
fi

rm -rf "$2"
mkdir -p "$2"
TARGET_ABS=$(readlink -f "$2")

ARCH=$1
if [ "$ARCH" = "i386" ]; then
    echo "i386 is not supported in Ubuntu 24.04 (Noble)"
    exit 1
fi

# Determine download URL
# Ubuntu Base 24.04.4 is the current release.
VERSION="24.04.4"
BASE_URL="http://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release"

if [ "$ARCH" = "amd64" ] || [ "$ARCH" = "arm64" ] || [ "$ARCH" = "armhf" ]; then
    echo "Downloading Ubuntu Base ${VERSION} for ${ARCH}..."
    wget -q "${BASE_URL}/ubuntu-base-${VERSION}-base-${ARCH}.tar.gz" -O ubuntu-base.tar.gz
    echo "Extracting..."
    tar -xzf ubuntu-base.tar.gz -C "$2"
    rm ubuntu-base.tar.gz
else
    echo "Unknown or unsupported architecture: $ARCH"
    exit 1
fi

# Fix permission on dev machine only for easy packing
chmod 777 -R "$2"

# This step is only needed for Ubuntu to prevent Group error
touch "$2/root/.hushlogin"

# Setup DNS
echo "127.0.0.1 localhost" > "$2/etc/hosts"
echo "nameserver 8.8.8.8" > "$2/etc/resolv.conf"
echo "nameserver 8.8.4.4" >> "$2/etc/resolv.conf"

# sources.list setup
rm "$2/etc/apt/sources.list"
rm "$2/etc/hostname"
echo "AnLinux-Ubuntu" > "$2/etc/hostname"

# Use noble repos
if [ "$ARCH" = "amd64" ]; then
  echo "deb http://archive.ubuntu.com/ubuntu noble main restricted universe multiverse" >> "$2/etc/apt/sources.list"
  echo "deb http://archive.ubuntu.com/ubuntu noble-backports main restricted universe multiverse" >> "$2/etc/apt/sources.list"
  echo "deb http://archive.ubuntu.com/ubuntu noble-proposed main restricted universe multiverse" >> "$2/etc/apt/sources.list"
  echo "deb http://archive.ubuntu.com/ubuntu noble-security main restricted universe multiverse" >> "$2/etc/apt/sources.list"
  echo "deb http://archive.ubuntu.com/ubuntu noble-updates main restricted universe multiverse" >> "$2/etc/apt/sources.list"
  echo "deb-src http://archive.ubuntu.com/ubuntu noble main restricted universe multiverse" >> "$2/etc/apt/sources.list
else
  # arm64, armhf use ports
  echo "deb http://ports.ubuntu.com/ubuntu-ports noble main restricted universe multiverse" >> "$2/etc/apt/sources.list"
  echo "deb http://ports.ubuntu.com/ubuntu-ports noble-backports main restricted universe multiverse" >> "$2/etc/apt/sources.list"
  echo "deb http://ports.ubuntu.com/ubuntu-ports noble-proposed main restricted universe multiverse" >> "$2/etc/apt/sources.list"
  echo "deb http://ports.ubuntu.com/ubuntu-ports noble-security main restricted universe multiverse" >> "$2/etc/apt/sources.list"
  echo "deb http://ports.ubuntu.com/ubuntu-ports noble-updates main restricted universe multiverse" >> "$2/etc/apt/sources.list"
  echo "deb-src http://ports.ubuntu.com/ubuntu-ports noble main restricted universe multiverse" >> "$2/etc/apt/sources.list
fi

# Prepare for chroot execution
# Copy qemu binary if needed
QEMU_COPIED=false
if [ "$ARCH" != "amd64" ] && [ "$(uname -m)" = "x86_64" ]; then
    # Assume qemu-user-static is installed on host
    if [ "$ARCH" = "arm64" ]; then
        if [ -f /usr/bin/qemu-aarch64-static ]; then
            cp /usr/bin/qemu-aarch64-static "$2/usr/bin/"
            QEMU_COPIED=true
        else
            echo "Warning: /usr/bin/qemu-aarch64-static not found."
        fi
    elif [ "$ARCH" = "armhf" ]; then
        if [ -f /usr/bin/qemu-arm-static ]; then
            cp /usr/bin/qemu-arm-static "$2/usr/bin/"
            QEMU_COPIED=true
        else
            echo "Warning: /usr/bin/qemu-arm-static not found."
        fi
    fi
fi

# Mount proc, dev, sys for apt to work in chroot
mount -t proc /proc "$2/proc"
mount -o bind /dev "$2/dev"
mount -o bind /sys "$2/sys"

# Trap to unmount in case of error
cleanup() {
    umount "$2/proc" || true
    umount "$2/dev" || true
    umount "$2/sys" || true
}
trap cleanup EXIT

# Setup custom packages
DEBIAN_FRONTEND=noninteractive chroot "$2" apt-get update
DEBIAN_FRONTEND=noninteractive chroot "$2" apt-get install -y systemd libsystemd0 wget ca-certificates busybox-static gvfs-daemons udisks2

# Cleanup udisks2 postinst as in original
chroot "$2" rm /var/lib/dpkg/info/udisks2.postinst || true
DEBIAN_FRONTEND=noninteractive chroot "$2" dpkg --configure udisks2
DEBIAN_FRONTEND=noninteractive chroot "$2" apt-get install -f
DEBIAN_FRONTEND=noninteractive chroot "$2" apt-get clean
DEBIAN_FRONTEND=noninteractive chroot "$2" apt-get autoremove -y
rm -rf "$2/var/lib/apt/lists/*"

# Clean up qemu binary if we copied it
if [ "$QEMU_COPIED" = true ]; then
    if [ "$ARCH" = "arm64" ]; then
        rm "$2/usr/bin/qemu-aarch64-static"
    elif [ "$ARCH" = "armhf" ]; then
        rm "$2/usr/bin/qemu-arm-static"
    fi
fi

# Unmount explicitly
umount "$2/proc"
umount "$2/dev"
umount "$2/sys"
trap - EXIT

# tar the rootfs
cd "$2"
rm -rf ../ubuntu-rootfs-$1.tar.xz
# Be very careful with rm -rf dev/* to ensure we are in the right place and dev is not mounted
if [ "$(pwd)" = "$TARGET_ABS" ]; then
    # Check if dev is mounted
    if mountpoint -q dev; then
        echo "Error: dev is still mounted! Aborting cleanup to protect host."
        exit 1
    fi
    rm -rf dev/*
else
    echo "Error: Directory mismatch before cleaning /dev"
    exit 1
fi
XZ_OPT=-9 tar -cJvf ../ubuntu-rootfs-$1.tar.xz ./*
