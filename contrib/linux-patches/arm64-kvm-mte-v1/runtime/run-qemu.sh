#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only

set -euo pipefail

if (( $# != 3 )) || [[ $3 != panic && $3 != pass ]]; then
	printf 'usage: %s IMAGE INITRAMFS {panic|pass}\n' "$0" >&2
	exit 2
fi

kernel_image=$(realpath "$1")
initramfs=$(realpath "$2")
expected_result=$3
qemu_binary=${QEMU_SYSTEM_AARCH64:-qemu-system-aarch64}
timeout_seconds=${QEMU_TIMEOUT_SECONDS:-300}
serial_log=$(mktemp)
trap 'rm -f -- "$serial_log"' EXIT

set +e
timeout --signal=TERM "$timeout_seconds" "$qemu_binary" \
	-machine virt,mte=on,virtualization=on,gic-version=3 \
	-cpu max -accel tcg,thread=multi -smp 2 -m 1024 \
	-nographic -no-reboot \
	-kernel "$kernel_image" -initrd "$initramfs" \
	-append 'console=ttyAMA0 earlycon=pl011,0x09000000 rdinit=/init panic=-1 panic_on_warn=1 hugepagesz=2M hugepages=2 nokaslr' \
	> "$serial_log" 2>&1
qemu_status=$?
set -e

cat "$serial_log"

if (( qemu_status != 0 )); then
	printf 'QEMU exited with status %d\n' "$qemu_status" >&2
	exit 1
fi

if ! grep -q 'CPU features: detected: Memory Tagging Extension' "$serial_log" ||
	! grep -q 'CPU: All CPU(s) started at EL2' "$serial_log" ||
	! grep -q 'VHE mode initialized successfully' "$serial_log" ||
	! grep -q 'HugeTLB: registered 2.00 MiB page size, pre-allocated 2 pages' \
		"$serial_log" ||
	! grep -q '^FRAMA_KVM_MTE_RUNTIME_BEGIN' "$serial_log" ||
	! grep -q '^FRAMA_KVM_MTE_IOCTL_BEGIN' "$serial_log"; then
	printf 'ARM64 MTE, EL2/KVM, hugetlb, or test markers are missing\n' >&2
	exit 1
fi

if grep -q '^FRAMA_KVM_MTE_SETUP_ERROR' "$serial_log"; then
	printf 'runtime setup failed\n' >&2
	exit 1
fi

case "$expected_result" in
panic)
	grep -q 'WARNING: arch/arm64/include/asm/mte.h:58 at kvm_vm_ioctl_mte_copy_tags' \
		"$serial_log"
	grep -q 'Kernel panic - not syncing: kernel: panic_on_warn set' \
		"$serial_log"
	if grep -q '^FRAMA_KVM_MTE_IOCTL_PASS' "$serial_log"; then
		printf 'vulnerable control unexpectedly completed the ioctl\n' >&2
		exit 1
	fi
	;;
pass)
	grep -q '^FRAMA_KVM_MTE_IOCTL_PASS bytes=4096' "$serial_log"
	grep -q '^FRAMA_KVM_MTE_RUNTIME_RESULT=PASS exit=0' "$serial_log"
	if grep -q 'WARNING: arch/arm64/include/asm/mte.h:58 at kvm_vm_ioctl_mte_copy_tags' \
		"$serial_log" || grep -q 'Kernel panic - not syncing' "$serial_log"; then
		printf 'fixed control emitted the target warning or panicked\n' >&2
		exit 1
	fi
	;;
esac
