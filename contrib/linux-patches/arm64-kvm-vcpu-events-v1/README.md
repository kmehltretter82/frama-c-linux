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

- A bounded Frama-C/Eva replay proves that the vulnerable order returns
  `-EINVAL` after changing PC from 256 to 512, PSTATE from 0 to 965, and the
  committed-abort marker from 0 to 1. Its atomic-rejection assertion is invalid.
- The validation-first replay proves both rejection and unchanged-state
  assertions. Both runs report zero Eva runtime alarms.
- Linux history identifies `77ee70a07357` as the commit that moved SError
  validation after external-abort injection; the patch carries that `Fixes:`
  tag.
- `scripts/checkpatch.pl --strict` reports zero errors, warnings, or checks.
- ARM64 KVM `guest.o` builds with `W=1`, and the modified
  `arm64/external_aborts` KVM selftest cross-builds with GCC.
- A Sashiko-style source review checked the ioctl call chain, vCPU mutex,
  exception helpers, error paths, and selftest behavior. It found no remaining
  regression after correcting the draft's provenance tag and style issue.

No ARM64 KVM runtime execution has been performed yet. Maintainer review,
runtime testing on ARM64, and upstream acceptance remain necessary before
treating the bug or fix as closed.
