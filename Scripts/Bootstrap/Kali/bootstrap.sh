#!/usr/bin/env bash

#Bootstrap the system
# $1: Architecture
# $2: Target directory

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: $0 <architecture> <directory>"
  exit 1
fi

TARGET_DIR=$(readlink -f "$2")

rm -rf "$TARGET_DIR"
mkdir -p "$TARGET_DIR"

if [ "$1" = "i386" ] || [ "$1" = "amd64" ] ; then
  debootstrap --arch=$1 --variant=minbase --include=systemd,libsystemd0,wget,ca-certificates,busybox-static,gnupg kali-rolling "$TARGET_DIR" http://http.kali.org/kali
else
  qemu-debootstrap --arch=$1 --variant=minbase --include=systemd,libsystemd0,wget,ca-certificates,busybox-static,gnupg kali-rolling "$TARGET_DIR" http://http.kali.org/kali
fi

#Reduce size
DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
 LC_ALL=C LANGUAGE=C LANG=C chroot "$TARGET_DIR" apt-get clean

#Fix permission on dev machine only for easy packing
chmod 777 -R "$TARGET_DIR"

#Setup DNS
echo "127.0.0.1 localhost" > "$TARGET_DIR/etc/hosts"
echo "nameserver 8.8.8.8" > "$TARGET_DIR/etc/resolv.conf"
echo "nameserver 8.8.4.4" >> "$TARGET_DIR/etc/resolv.conf"

#sources.list setup
rm "$TARGET_DIR/etc/apt/sources.list"
rm "$TARGET_DIR/etc/hostname"
echo "AnLinux-Kali" > "$TARGET_DIR/etc/hostname"

COMPONENTS="main contrib non-free non-free-firmware"

echo "deb http://http.kali.org/kali kali-rolling $COMPONENTS" >> "$TARGET_DIR/etc/apt/sources.list"
echo "deb-src http://http.kali.org/kali kali-rolling $COMPONENTS" >> "$TARGET_DIR/etc/apt/sources.list"

#Import the gpg key, this is only required in Kali
chroot "$TARGET_DIR" wget http://archive.kali.org/archive-key.asc -O /etc/apt/trusted.gpg.d/kali-archive-key.asc

#setup custom packages
chroot "$TARGET_DIR" apt-get update
chroot "$TARGET_DIR" apt-get install gvfs-daemons udisks2 -y
chroot "$TARGET_DIR" rm /var/lib/dpkg/info/udisks2.postinst || true
chroot "$TARGET_DIR" dpkg --configure udisks2
chroot "$TARGET_DIR" apt-get install -f
chroot "$TARGET_DIR" apt-get clean
chroot "$TARGET_DIR" apt-get autoremove -y
rm -rf "$TARGET_DIR/var/lib/apt/lists/*"

#tar the rootfs
cd "$TARGET_DIR"
rm -rf ../kali-rootfs-$1.tar.xz
rm -rf dev/*
XZ_OPT=-9 tar -cJvf ../kali-rootfs-$1.tar.xz ./*
