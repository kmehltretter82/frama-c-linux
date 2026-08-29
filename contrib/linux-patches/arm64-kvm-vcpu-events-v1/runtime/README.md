# Focused ARM64 KVM runtime reproducer

This runner executes only `test_rejected_events()` from the Linux selftest
added by the adjacent patch. It includes the patched tree's real
`external_aborts.c`, so KVM setup, the ioctl, and guest assertions are not
duplicated here. A tiny static init starts the test and emits one
machine-readable result marker.

The recorded control used Linux baseline `548e7bcd0c54` and fixed revision
`fd918c259a80`, QEMU 10.2.1 TCG, `virt,virtualization=on`, `-cpu max`, two
vCPUs, GICv3, and a kernel that starts all CPUs at EL2 and initializes KVM in
VHE mode. It used GCC 15.2.0 and binutils 2.46 as the ARM64 cross toolchain.

## Build

The host needs an ARM64 static cross libc, `aarch64-linux-gnu-gcc`, QEMU's
`qemu-system-aarch64`, `cpio`, and normal Linux build dependencies.

Configure both kernel builds identically:

```sh
runtime/configure-kernel.sh "$LINUX_BASELINE" "$OUT/baseline"
runtime/configure-kernel.sh "$LINUX_FIXED" "$OUT/fixed"
make -C "$LINUX_BASELINE" O="$OUT/baseline" ARCH=arm64 \
  CROSS_COMPILE=aarch64-linux-gnu- -j"$(nproc)" Image
make -C "$LINUX_FIXED" O="$OUT/fixed" ARCH=arm64 \
  CROSS_COMPILE=aarch64-linux-gnu- -j"$(nproc)" Image
```

The configuration helper starts from ARM64 `defconfig`, disables unrelated
large subsystems and debug information, and leaves the defconfig's KVM,
PL011, GICv3, devtmpfs, proc, sysfs, and tmpfs support enabled. For the
recorded run, the resulting `.config` SHA-256 was
`c06c2f0924059ee962a14f96f0377190a86dc034a3f985116fd0dd918ea2b9bb`.

Build the focused test from the patched Linux tree and create its static
initramfs:

```sh
runtime/build-userspace.sh "$LINUX_FIXED" "$OUT/userspace"
```

`build-userspace.sh` first lets the upstream KVM selftest Makefile generate
headers and build libkvm. It then compiles the tracked wrapper with the same
include and ABI flags, links it statically, builds `init.c`, and creates a
small `newc` initramfs. No generated binary belongs in Git.

## Run the differential

```sh
runtime/run-qemu.sh "$OUT/baseline/arch/arm64/boot/Image" \
  "$OUT/userspace/initramfs.cpio" fail
runtime/run-qemu.sh "$OUT/fixed/arch/arm64/boot/Image" \
  "$OUT/userspace/initramfs.cpio" pass
```

The vulnerable kernel reaches `unexpected_dabt_handler()` and reports:

```text
Unexpected data abort at PC: 400c6c
FRAMA_KVM_RUNTIME_RESULT=FAIL exit=254
```

With only the candidate kernel patch changed, the same focused binary and
initramfs report:

```text
FRAMA_KVM_RUNTIME_RESULT=PASS exit=0
```

The exact artifact identities and result classification are recorded in
[`result-v1.json`](result-v1.json). This is a runtime confirmation under an
emulated ARM64 EL2/KVM environment, not physical-hardware coverage, maintainer
review, or upstream acceptance.
