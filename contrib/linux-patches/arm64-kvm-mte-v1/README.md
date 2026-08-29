# ARM64 KVM MTE candidate fixes (v1)

This directory preserves the first Linux patch series produced from a fresh
Frama-C Linux ARM64 KVM finding. The four files are mail-formatted patches
against Linux commit `548e7bcd0c5460ddcbca9600cea603ebeebf4da7`.

The series is a review candidate, not an upstream-accepted fix. Rebase it onto
the intended maintainer tree and repeat the checks before submission.

## Patch map

1. Add a non-faulting kernel-buffer tag import helper and a shared helper that
   initializes every base page in an MTE hugetlb folio.
2. Stage userspace tag bytes before acquiring the one-shot MTE initialization
   state, avoiding a fault-under-initialization deadlock, and initialize the
   complete hugetlb folio before publishing its tagged state.
3. Make the KVM stage-2 sanitizer initialize the complete hugetlb folio rather
   than only the current mapping granule.
4. Keep fresh hugetlb tag reads out of `page_mte_tagged()`, whose debug guard
   rejects hugetlb pages.

Apply the series in numeric order with:

```sh
git am /path/to/arm64-kvm-mte-v1/*.patch
```

## Evidence recorded for v1

- The exact Kbuild-mapped checker run reports one MTE initialization ordering
  violation at baseline `guest.c:1051` and none after the series. Both bounded
  Eva runs complete with zero alarms.
- The path-sensitive MTE helper-domain rule reports the fresh-hugetlb
  `page_mte_tagged()` fall-through once in the complete baseline `guest.c` and
  zero times with only patch 4 applied.
- The Frama-C checker recognizes both the original MTE helper and ordinary
  direct user-copy helpers, so the fixed result still checks that the staged
  `copy_from_user()` remains before initialization acquisition.
- `scripts/checkpatch.pl --strict` reports no errors, warnings, or checks for
  all four patches.
- ARM64 `W=1` builds pass for the affected MTE and KVM objects and the complete
  `arch/arm64/kvm/` directory with MTE, hugetlb, and KVM enabled. Focused
  configurations without hugetlb and without MTE also compile.
- A multi-pass source review found a zero-length ioctl regression in an
  earlier draft; v1 preserves the existing zero-length no-op behavior.
- The Frama-C plug-in build and focused test suite pass, including positive,
  fixed-order, and misplaced-staging controls.
- A focused `KVM_ARM_MTE_COPY_TAGS` run under QEMU ARM64 MTE/EL2/KVM makes the
  baseline kernel warn in `page_mte_tagged()` and panic under `panic_on_warn`.
  With the identical trigger, initramfs, configuration, and QEMU command, the
  baseline plus only patch 4 completes the 4096-byte ioctl and exits zero.

This runtime differential confirms the patch-4 Linux bug under QEMU TCG; it
does not runtime-confirm the defects addressed by patches 1 through 3.
Physical ARM64 testing, maintainer review, and upstream acceptance remain
necessary before treating any fix as closed. Reproducer source and compact
artifact identities are in [`runtime/`](runtime/).
