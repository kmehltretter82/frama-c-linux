# Focused ARM64 KVM MTE runtime reproducer

This reproducer creates an MTE-enabled KVM VM backed by a fresh anonymous
2 MiB hugetlb folio, then asks `KVM_ARM_MTE_COPY_TAGS` to read one base page's
tags. The fresh folio is intentionally untagged. On the vulnerable source,
the boolean expression in `kvm_vm_ioctl_mte_copy_tags()` falls through from
the hugetlb helper to `page_mte_tagged()`, whose `VM_WARN_ON_ONCE()` rejects
hugetlb pages. `panic_on_warn=1` turns that valid ioctl into a host panic.

The recorded differential used Linux baseline `548e7bcd0c54` and the same
baseline with only adjacent patch 4 applied. It ran under QEMU 10.2.1 TCG on
`virt,mte=on,virtualization=on`, with `-cpu max`, two vCPUs, GICv3, and two
preallocated 2 MiB hugepages. All CPUs started at EL2, KVM initialized in VHE
mode, and the guest detected ARM64 MTE. GCC 15.2.0 and binutils 2.46 supplied
the ARM64 cross toolchain.

## Build

The host needs an ARM64 static cross libc, `aarch64-linux-gnu-gcc`, QEMU's
`qemu-system-aarch64`, `cpio`, and normal Linux build dependencies.

Configure and build identical vulnerable and fixed kernels:

```sh
runtime/configure-kernel.sh "$LINUX_VULNERABLE" "$OUT/vulnerable"
runtime/configure-kernel.sh "$LINUX_FIXED" "$OUT/fixed"
make -C "$LINUX_VULNERABLE" O="$OUT/vulnerable" ARCH=arm64 \
  CROSS_COMPILE=aarch64-linux-gnu- -j"$(nproc)" Image
make -C "$LINUX_FIXED" O="$OUT/fixed" ARCH=arm64 \
  CROSS_COMPILE=aarch64-linux-gnu- -j"$(nproc)" Image
```

`$LINUX_FIXED` means baseline `548e7bcd0c54` plus only patch 4, not the full
four-patch MTE series. The configuration enables MTE, `DEBUG_VM`, hugetlb,
KVM, PL011, and the filesystems needed by the tiny initramfs, while disabling
unrelated large subsystems. Its recorded SHA-256 is
`898f98436130657dd920265c1375a349d0e596eb52f98a61e386c3c0e6746bd8`.

Build the static ioctl trigger and initramfs:

```sh
runtime/build-initramfs.sh "$OUT/userspace"
```

No generated kernel, binary, initramfs, or full serial log belongs in Git.

## Run the differential

```sh
runtime/run-qemu.sh "$OUT/vulnerable/arch/arm64/boot/Image" \
  "$OUT/userspace/initramfs.cpio" panic
runtime/run-qemu.sh "$OUT/fixed/arch/arm64/boot/Image" \
  "$OUT/userspace/initramfs.cpio" pass
```

The vulnerable kernel reports the target warning from `mte.h:58` in
`kvm_vm_ioctl_mte_copy_tags()` and then panics. With only patch 4 changed, the
same trigger reports:

```text
FRAMA_KVM_MTE_IOCTL_PASS bytes=4096
FRAMA_KVM_MTE_RUNTIME_RESULT=PASS exit=0
```

Exact artifact identities and the static one-finding/zero-finding control are
recorded in [`result-v1.json`](result-v1.json). This is runtime confirmation
under an emulated ARM64 EL2/KVM environment, not physical-hardware coverage,
maintainer review, or upstream acceptance.
