#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only

set -euo pipefail

if (( $# != 2 )); then
	printf 'usage: %s LINUX_SOURCE KERNEL_BUILD\n' "$0" >&2
	exit 2
fi

linux_source=$(realpath "$1")
kernel_build=$(realpath -m "$2")
cross_compile=${CROSS_COMPILE:-aarch64-linux-gnu-}

make -C "$linux_source" O="$kernel_build" ARCH=arm64 \
	CROSS_COMPILE="$cross_compile" defconfig

"$linux_source/scripts/config" --file "$kernel_build/.config" \
	--set-str LOCALVERSION -frama-kvm-runtime \
	--disable LOCALVERSION_AUTO \
	--enable DEBUG_INFO_NONE \
	--disable DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT \
	--disable MODULES \
	--disable NET \
	--disable PCI \
	--disable EFI \
	--disable DRM \
	--disable MEDIA_SUPPORT \
	--disable SOUND \
	--disable HID \
	--disable USB_SUPPORT \
	--disable MMC \
	--disable MTD \
	--disable SCSI \
	--disable ATA \
	--disable I2C \
	--disable SPI \
	--disable BPF_SYSCALL

make -C "$linux_source" O="$kernel_build" ARCH=arm64 \
	CROSS_COMPILE="$cross_compile" olddefconfig
sha256sum "$kernel_build/.config"
