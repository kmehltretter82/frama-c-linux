#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only

set -euo pipefail

if (( $# != 3 )); then
	printf 'usage: %s LINUX_SOURCE KERNEL_BUILD OUTPUT_DIRECTORY\n' "$0" >&2
	exit 2
fi

linux_source=$(realpath "$1")
kernel_build=$(realpath "$2")
output_directory=$(realpath -m "$3")
runtime_directory=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cross_compile=${CROSS_COMPILE:-aarch64-linux-gnu-}
cross_cc="${cross_compile}gcc"
headers="$output_directory/headers"

mkdir -p "$output_directory"
make -C "$linux_source" O="$kernel_build" ARCH=arm64 \
	CROSS_COMPILE="$cross_compile" headers_install \
	INSTALL_HDR_PATH="$headers"

"$cross_cc" -static -O2 -Wall -Wextra -Werror -std=gnu11 \
	-I"$headers/include" "$runtime_directory/smccc_filter_repro.c" \
	-o "$output_directory/smccc_filter_repro"
"$cross_cc" -static -O2 -Wall -Wextra -Werror -std=gnu11 \
	"$runtime_directory/init.c" -o "$output_directory/init"

initramfs_root=$(mktemp -d "$output_directory/initramfs-root.XXXXXX")
trap 'rm -rf -- "$initramfs_root"' EXIT
mkdir -p "$initramfs_root/dev" "$initramfs_root/proc" \
	"$initramfs_root/sys/kernel/debug"
install -m 0755 "$output_directory/init" "$initramfs_root/init"
install -m 0755 "$output_directory/smccc_filter_repro" \
	"$initramfs_root/smccc_filter_repro"
(
	cd "$initramfs_root"
	find . -print0 | LC_ALL=C sort -z | \
		cpio --null --create --format=newc --quiet
) > "$output_directory/initramfs.cpio"

sha256sum "$output_directory/smccc_filter_repro" \
	"$output_directory/init" "$output_directory/initramfs.cpio"
