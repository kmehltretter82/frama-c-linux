# ARM64 KVM empty SMCCC filter range

This two-patch series fixes the `base == 0 && nr_functions == 0` boundary in
`KVM_ARM_VM_SMCCC_FILTER` and adds the missing selftest case. It is based on
Linux `548e7bcd0c5460ddcbca9600cea603ebeebf4da7` and was sent to the KVM lists
on 2026-08-29. Maintainer confirmation and upstream acceptance remain pending.

The UAPI range is half-open, but KVM converts it to an inclusive end. For an
empty range at base zero, unsigned arithmetic produced `U32_MAX`; insertion of
that accidental full-ID range then collided with KVM's reserved architecture
ranges. The observable result was `-EEXIST` after filter state had changed,
rather than immediate `-EINVAL` for the invalid request.

The first patch rejects a zero count explicitly. The second extends
`test_invalid_nr_functions()` with the base-zero boundary. A focused userspace
control on an ARM64 KVM VHE host under QEMU TCG observed `EEXIST` before the
fix and `EINVAL` afterward.

The `runtime/` scripts retain the small source needed to rebuild that control.
Generated kernel images, binaries, initramfs archives, and serial logs are
intentionally not tracked.
