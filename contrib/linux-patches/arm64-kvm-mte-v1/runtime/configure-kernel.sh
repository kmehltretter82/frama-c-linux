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
	--set-str LOCALVERSION -frama-kvm-mte-runtime \
	--disable LOCALVERSION_AUTO \
	--enable DEBUG_INFO_NONE \
	--disable DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT \
	--enable ARM64_MTE \
	--enable DEBUG_VM \
	--enable HUGETLBFS \
	--enable KVM \
	--enable VIRTUALIZATION \
	--enable DEVTMPFS \
	--enable DEVTMPFS_MOUNT \
	--enable SERIAL_AMBA_PL011 \
	--enable SERIAL_AMBA_PL011_CONSOLE \
	--enable PROC_FS \
	--enable SYSFS \
	--enable TMPFS \
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

for symbol in ARM64_MTE DEBUG_VM HUGETLBFS HUGETLB_PAGE KVM \
	VIRTUALIZATION DEVTMPFS DEVTMPFS_MOUNT SERIAL_AMBA_PL011_CONSOLE \
	PROC_FS SYSFS TMPFS; do
	if [[ $("$linux_source/scripts/config" --file "$kernel_build/.config" \
		--state "$symbol") != y ]]; then
		printf 'required CONFIG_%s=y was not selected\n' "$symbol" >&2
		exit 1
	fi
done

sha256sum "$kernel_build/.config"
