# ARM64 KVM vCPU-events atomicity fix (v1)

This directory preserves a Linux patch produced from a fresh Frama-C Linux
ARM64 KVM finding. The mail-formatted patch applies to Linux commit
`548e7bcd0c5460ddcbca9600cea603ebeebf4da7`, which was current upstream master
when the issue was revalidated on 2026-08-28.

The patch is a review candidate, not an upstream-accepted fix. Rebase it onto
the intended KVM/arm64 maintainer tree and repeat the checks before submission.

## Bug and fix

`KVM_SET_VCPU_EVENTS` accepts external data-abort and SError requests in one
structure. Current ARM64 KVM injects and immediately commits the external
abort before validating the SError ESR. A request with a valid external abort
and an invalid SError ESR therefore returns `-EINVAL` after modifying PC,
PSTATE, exception, and MMIO-completion state.

The patch validates the complete SError request before injecting either event.
It also adds an ARM64 KVM selftest that submits this combined request after an
MMIO exit. The fixed kernel rejects it and then completes the MMIO instruction
normally; the vulnerable ordering commits the external abort instead.

Apply the patch with:

```sh
git am 0001-KVM-arm64-Validate-vCPU-events-before-committing-st.patch
```

## Evidence recorded for v1

- The exact ARM64 Kbuild command maps the tracked
  `arm64_kvm_vcpu_events.c` harness onto the complete baseline `guest.c`.
  Eva evaluates the real `__kvm_arm_vcpu_set_events()` and proves that it
  returns `-EINVAL` after changing PC from 256 to 512, PSTATE from 0 to 965,
  and the committed-abort marker from 0 to 1. The rejected-request atomicity
  assertion is invalid.
- Mapping the same harness and command onto the patched complete `guest.c`
  proves both the rejection and unchanged-state assertions. Both full-source
  runs report zero Eva runtime alarms; the baseline reaches 73/103 selected
  statements in 9/158 functions, while the fixed control reaches 37/60 in
  4/158 functions.
- Reduced before/fixed tests preserve the same differential in the ordinary
  `kernel-checks` regression suite.
- Linux history identifies `77ee70a07357` as the commit that moved SError
  validation after external-abort injection. The original external-abort
  implementation in `da345174ceca` validated SError first, so the patch
  restores the earlier ordering and carries the corresponding `Fixes:` tag.
- `scripts/checkpatch.pl --strict` reports zero errors, warnings, or checks.
- ARM64 KVM `guest.o` builds with `W=1`, and the modified
  `arm64/external_aborts` KVM selftest cross-builds with GCC.
- A Sashiko-style source review checked the ioctl call chain, vCPU mutex,
  exception helpers, error paths, and selftest behavior. It found no remaining
  regression after correcting the draft's provenance tag and style issue.
- A focused runner executed only the new regression test under QEMU ARM64 TCG
  with all CPUs at EL2 and KVM in VHE mode. With the same test binary,
  initramfs, QEMU command, and kernel configuration, baseline
  `548e7bcd0c54` reaches `unexpected_dabt_handler()` and exits 254, while fixed
  `fd918c259a80` exits 0. The compact evidence and reproduction helpers are in
  [`runtime`](runtime/).

This is one runtime-confirmed Linux ARM64 KVM bug under an emulated EL2/KVM
environment. Physical ARM64 coverage, maintainer review, and upstream
acceptance remain necessary before treating the fix as closed.
