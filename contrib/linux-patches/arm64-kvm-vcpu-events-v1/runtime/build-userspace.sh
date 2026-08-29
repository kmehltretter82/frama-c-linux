#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only

set -euo pipefail

if (( $# != 2 )); then
	printf 'usage: %s PATCHED_LINUX_SOURCE OUTPUT_DIRECTORY\n' "$0" >&2
	exit 2
fi

linux_source=$(realpath "$1")
output_directory=$(realpath -m "$2")
runtime_directory=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
kvm_directory="$linux_source/tools/testing/selftests/kvm"
selftest_output="$output_directory/selftests"
cross_compile=${CROSS_COMPILE:-aarch64-linux-gnu-}
cross_cc="${cross_compile}gcc"
external_aborts="$kvm_directory/arm64/external_aborts.c"

if ! grep -q 'static void test_rejected_events(void)' "$external_aborts"; then
	printf '%s does not contain the regression test\n' "$external_aborts" >&2
	exit 1
fi

mkdir -p "$selftest_output/arm64"

# Build the upstream target first to generate headers and all libkvm objects.
make -C "$kvm_directory" ARCH=arm64 CROSS_COMPILE="$cross_compile" \
	OUTPUT="$selftest_output" USERLDFLAGS=-static \
	"$selftest_output/arm64/external_aborts"

common_cflags=(
	-D_GNU_SOURCE=
	-Wall -Wstrict-prototypes -Wuninitialized -Werror
	-O2 -g -std=gnu99
	-Wno-gnu-variable-sized-type-not-at-end
	-MD -MP -DCONFIG_64BIT -U_FORTIFY_SOURCE
	-fno-builtin-memcmp -fno-builtin-memcpy -fno-builtin-memset
	-fno-builtin-strnlen -fno-stack-protector -fno-PIE
	-fno-strict-aliasing
	"-I$linux_source/tools/testing/selftests"
	"-I$linux_source/tools/testing/selftests/cgroup/lib/include"
	"-I$linux_source/tools/include"
	"-I$linux_source/tools/arch/arm64/include"
	"-I$linux_source/usr/include"
	"-I$kvm_directory/include"
	"-I$kvm_directory/arm64"
	"-I$kvm_directory/include/arm64"
	"-I$linux_source/tools/testing/selftests/rseq"
	-isystem "$linux_source/usr/include"
	"-I$linux_source/tools/arch/arm64/include/generated"
)

focused_object="$selftest_output/arm64/rejected_events.o"
focused_binary="$selftest_output/arm64/rejected_events"

"$cross_cc" "${common_cflags[@]}" \
	"-DEXTERNAL_ABORTS_SOURCE=\"$external_aborts\"" \
	-c "$runtime_directory/focused_external_aborts.c" \
	-o "$focused_object"

mapfile -d '' library_objects < <(
	find "$selftest_output/lib" -type f -name '*.o' -print0 | sort -z
)
"$cross_cc" -static -pthread -no-pie "$focused_object" \
	"${library_objects[@]}" -ldl -o "$focused_binary"

"$cross_cc" -static -O2 -Wall -Wextra -Werror -std=gnu11 \
	"$runtime_directory/init.c" -o "$output_directory/init"

initramfs_root=$(mktemp -d "$output_directory/initramfs-root.XXXXXX")
trap 'rm -rf -- "$initramfs_root"' EXIT
mkdir -p "$initramfs_root/dev" "$initramfs_root/proc" "$initramfs_root/sys"
install -m 0755 "$output_directory/init" "$initramfs_root/init"
install -m 0755 "$focused_binary" "$initramfs_root/rejected_events"
(
	cd "$initramfs_root"
	find . -print0 | LC_ALL=C sort -z | \
		cpio --null --create --format=newc --quiet
) > "$output_directory/initramfs.cpio"

sha256sum "$focused_binary" "$output_directory/init" \
	"$output_directory/initramfs.cpio"
