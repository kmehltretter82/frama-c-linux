#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only

set -euo pipefail

if (( $# != 1 )); then
	printf 'usage: %s OUTPUT_DIRECTORY\n' "$0" >&2
	exit 2
fi

output_directory=$(realpath -m "$1")
runtime_directory=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cross_compile=${CROSS_COMPILE:-aarch64-linux-gnu-}
cross_cc="${cross_compile}gcc"

mkdir -p "$output_directory"

"$cross_cc" -static -O2 -Wall -Wextra -Werror -std=gnu11 \
	"$runtime_directory/mte_hugetlb_read.c" \
	-o "$output_directory/mte_hugetlb_read"
"$cross_cc" -static -O2 -Wall -Wextra -Werror -std=gnu11 \
	"$runtime_directory/init.c" -o "$output_directory/init"

initramfs_root=$(mktemp -d "$output_directory/initramfs-root.XXXXXX")
trap 'rm -rf -- "$initramfs_root"' EXIT
mkdir -p "$initramfs_root/dev" "$initramfs_root/proc" \
	"$initramfs_root/sys"
install -m 0755 "$output_directory/init" "$initramfs_root/init"
install -m 0755 "$output_directory/mte_hugetlb_read" \
	"$initramfs_root/mte_hugetlb_read"
(
	cd "$initramfs_root"
	find . -print0 | LC_ALL=C sort -z | \
		cpio --null --create --format=newc --quiet
) > "$output_directory/initramfs.cpio"

sha256sum "$output_directory/mte_hugetlb_read" \
	"$output_directory/init" "$output_directory/initramfs.cpio"
