#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only

set -euo pipefail

if (( $# != 3 )) || [[ $3 != pass && $3 != fail ]]; then
	printf 'usage: %s IMAGE INITRAMFS {pass|fail}\n' "$0" >&2
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
	-machine virt,virtualization=on,gic-version=3 \
	-cpu max -accel tcg,thread=multi -smp 2 -m 1024 \
	-nographic -no-reboot \
	-kernel "$kernel_image" -initrd "$initramfs" \
	-append 'console=ttyAMA0 earlycon=pl011,0x09000000 rdinit=/init panic=-1 oops=panic nokaslr' \
	> "$serial_log" 2>&1
qemu_status=$?
set -e

cat "$serial_log"

if (( qemu_status != 0 )); then
	printf 'QEMU exited with status %d\n' "$qemu_status" >&2
	exit 1
fi

if ! grep -q 'CPU: All CPU(s) started at EL2' "$serial_log" ||
	! grep -q 'VHE mode initialized successfully' "$serial_log"; then
	printf 'ARM64 EL2/KVM initialization markers are missing\n' >&2
	exit 1
fi

case "$expected_result" in
pass)
	grep -q '^FRAMA_KVM_RUNTIME_RESULT=PASS exit=0$' "$serial_log"
	;;
fail)
	grep -q '^FRAMA_KVM_RUNTIME_RESULT=FAIL exit=' "$serial_log"
	grep -q 'Unexpected data abort at PC:' "$serial_log"
	;;
esac
