# Linux kernel checks

This plug-in contains Linux-specific semantic checks built on Frama-C Eva.
Enable it with `-kernel-checks`.

## ERR_PTR protocol

The first checker recognizes the Linux encoded-error pointer interval. For a
machine with `N`-bit pointers and the default `MAX_ERRNO` of 4095, encoded
errors occupy `[2^N - 4095, 2^N - 1]`. The equivalent signed interval
`[-4095, -1]` is accepted as well so the classification remains robust across
integer-to-pointer representations.

At each relevant operation, Eva's joined value is classified as one of:

- a definitely encoded error;
- `NULL`;
- a valid object pointer for the requested access; or
- unknown, including any mixture of the preceding classes.

Only definitely encoded errors produce diagnostics. The initial operations are
reads and writes through an encoded error, indirect calls through one, and
passing one to common kernel deallocation functions. Unknown values are not
reported as violations.

The deallocator policy currently recognizes the first pointer argument of
`kfree`, `kfree_sensitive`, `kvfree`, `kvfree_sensitive`, `vfree`, `free`,
the `kfree_skb*` family, `consume_skb`, `napi_consume_skb`, and the
`dev_kfree_skb*`/`dev_consume_skb*` families. It recognizes the second
argument of `devm_kfree`. Matching is by the directly called function name;
project-specific wrappers are not inferred yet.

Use `-kernel-checks-max-errno N` for a kernel with a non-default `MAX_ERRNO`.

By default, `-kernel-checks` disables Frama-C's creation-time invalid-pointer
and unaligned-pointer checks, plus its pointer-to-integer range check, before
running Eva. Those checks otherwise discard common typed `ERR_PTR(-errno)`
values or the signed `PTR_ERR()` conversion before the protocol checker can
inspect their uses. Eva's read/write validity checks remain enabled, so
dereferencing a misaligned or invalid pointer still raises the ordinary Eva
alarm in addition to the protocol-specific diagnostic. Use
`-kernel-checks-no-preserve-encoded-pointers` to retain the creation-time
checks.

## ARM64 MTE initialization protocol

The second checker targets a concrete ARM64 KVM locking protocol. The kernel's
`try_page_mte_tagging()` and `folio_try_hugetlb_mte_tagging()` helpers acquire
a one-shot initialization state that is released by publishing the matching
tagged bit. Calling faultable userspace access code while that state is held
can deadlock against a page-fault path that waits for publication.

The current rule is intentionally narrow. Within each defined function, it
performs a forward control-flow analysis and reports direct MTE tag-copy or
ordinary user-copy helpers when an ignored-result call to either initialization
helper may precede them and no tagged-state publication must have occurred.
The recognized direct calls are `mte_copy_tags_from_user()`,
`mte_copy_tags_to_user()`, `copy_from_user()`, `copy_to_user()`, and
`clear_user()`. It does not claim to be a general lock, alias, uaccess, or
interprocedural concurrency analysis. Storing and checking an acquisition
result is left unclassified rather than guessed about.

The checker inspects every function in the typed AST, independently of Eva's
selected entry-point reachability. On the complete pinned ARM64 KVM
`arch/arm64/kvm/guest.c` translation unit, this produces exactly one diagnostic
at the tag import in `kvm_vm_ioctl_mte_copy_tags()`. Eva intentionally analyzes
only the trivial bounded harness entry in this scan; the protocol result covers
all 160 function definitions parsed from the translation unit.

## Bounded callback and fault models

`-kernel-checks-bounded-entry` supplies a conservative finite default for
kernel callback analysis. Unless the corresponding options were explicitly
set, it enables `-lib-entry` and sets Eva context depth to 0 and context width
to 1. This avoids constructing unbounded recursive kernel objects. A harness
should construct any deeper objects required by the selected path.

`-kernel-checks-err-ptr-source f1,...,fn` maps each named pointer-returning
function to a side-effect-free Eva fault model that returns exactly
`ERR_PTR(-N)`. `N` defaults to 12 (`ENOMEM`) and can be selected with
`-kernel-checks-fault-errno N`; it must not exceed the configured `MAX_ERRNO`.
This is deliberate fault injection. A resulting diagnostic proves a protocol
violation under that failure outcome, not that the function always fails at
runtime.

`frama-c-script kernel-harness` creates a one-entry compilation database that
reuses an exact Kbuild command for a tracked harness:

```sh
frama-c-script kernel-harness \
  -p /path/to/compile_commands.json \
  --source /path/to/linux/net/openvswitch/datapath.c \
  --harness "$(frama-c -print-share-path)/kernel-harnesses/openvswitch_flow_cmd_set.c" \
  -o /tmp/openvswitch-harness.json
```

The mapper preserves argument boundaries, replaces only the selected source,
and adds its directory to the include path. `--source-override FILE` can place
a same-basename historical variant ahead of the checked-out source without
modifying the Linux tree.

Analyze the mapped Open vSwitch scenario with:

```sh
share_path=$(frama-c -print-share-path)
frama-c \
  -machdep gcc_x86_64 \
  -compilation-db /tmp/openvswitch-harness.json \
  "-cpp-extra-args=-include $share_path/kernel-models/compiler_builtins.h" \
  -main frama_c_ovs_flow_cmd_set_harness \
  -eva-slevel 10 \
  -kernel-checks \
  -kernel-checks-bounded-entry \
  -kernel-checks-err-ptr-source ovs_flow_cmd_build_info \
  "$share_path/kernel-harnesses/openvswitch_flow_cmd_set.c"
```

## Validation and scope

Focused tests cover the error-interval boundaries, mixed/unknown values,
32-bit and 64-bit machine models, configurable `MAX_ERRNO`, reads, writes,
indirect calls, and both first- and second-argument deallocators. The
fault-source before/fixed pair additionally runs under GCC x86_32, x86_64, and
ARM64 machine models, including a non-default injected errno. A reduced
replay of Linux commit `ee30dd2909d8b98619f4341c70ec8dc8e155ab02`
(`net: openvswitch: fix possible kfree_skb of ERR_PTR`) reports one provable
violation before the fix and none after it.

The tracked Open vSwitch harness adds bounded full-translation-unit evidence.
On the current fixed `datapath.c`, it analyzes 30/251 functions, reaches
145/232 statements, and reports zero violations. With only the one-line fix
from `ee30dd2909d8` reversed, it analyzes 30/251 functions, reaches 144/231
statements, and reports exactly one violation at `kfree_skb(reply)`. Both runs
have the same two unrelated Eva alarms.

The ARM64 KVM harness at
`kernel-harnesses/arm64_kvm_fw_reg.c` includes the complete current
`arch/arm64/kvm/hypercalls.c` translation unit and replays Linux fix
`a25bc8486f9c0`. Its modeled successful `copy_from_user()` requires both copy
extents to be valid. With a userspace-selected 16-byte register size, the
historical vulnerable prefix produces one invalid destination precondition;
the actual current function's 8-byte size guard produces none. Focused reduced
before/after tests enforce the same result under `gcc_arm64`.

The MTE protocol tests add one positive deadlock-shaped case and a non-faulting
kernel-copy control. A staged-uaccess test also accepts `copy_from_user()`
before initialization acquisition and reports the same call when deliberately
moved after acquisition. The tracked `kernel-harnesses/arm64_kvm_mte_scan.c`
harness includes the complete current `guest.c` and reports the one live
faultable-user-access violation described above. A separate reduced hugetlb
model captures the folio-wide validity invariant: Eva marks the assertion
invalid when one base page is initialized before publishing a folio-wide bit,
and proves it when all subpages are initialized first.

The candidate Linux series in
[`contrib/linux-patches/arm64-kvm-mte-v1`](../../contrib/linux-patches/arm64-kvm-mte-v1/)
turns the exact Kbuild-mapped full-source result from one MTE ordering
diagnostic at baseline `548e7bcd0c54` into none. The checker still recognizes
the staged `copy_from_user()`, so this fixed control remains sensitive to its
placement. The series is not an upstream-accepted fix and has not yet had an
ARM64 KVM runtime test.

Map and scan `guest.c` with its exact Kbuild command:

```sh
share_path=$(frama-c -print-share-path)
frama-c-script kernel-harness \
  -p /path/to/compile_commands.json \
  --source /path/to/linux/arch/arm64/kvm/guest.c \
  --harness "$share_path/kernel-harnesses/arm64_kvm_mte_scan.c" \
  -o /tmp/arm64-kvm-mte-scan.json
frama-c \
  -machdep gcc_arm64 \
  -compilation-db /tmp/arm64-kvm-mte-scan.json \
  "-cpp-extra-args=-include $share_path/kernel-models/compiler_builtins.h" \
  -main frama_c_arm64_kvm_mte_scan \
  -eva-slevel 1 \
  -kernel-checks \
  -kernel-checks-bounded-entry \
  "$share_path/kernel-harnesses/arm64_kvm_mte_scan.c"
```

Map the exact `hypercalls.c` Kbuild command as above, then select either
`frama_c_arm64_kvm_fw_reg_before` or
`frama_c_arm64_kvm_fw_reg_fixed` with `-main`, and run Eva with
`-machdep gcc_arm64 -eva-slevel 10`. The former is a reduced historical prefix
inside the complete current translation unit; it is not a historical kernel
checkout.

The Open vSwitch result establishes the checker on one explicit
allocation-failure scenario, not whole-kernel analysis coverage. Its harness
supplies selected objects and API outcomes, and the allocation is forced to
fail. Generic callback entry states, other outcomes, concurrency, and full
ownership semantics remain outside this result. A zero count from a shallow
direct translation-unit run remains inconclusive. The KVM result likewise
covers one oversized-register success path; it does not prove all ioctl inputs
or model unrelated ARM64 architectural effects. The MTE protocol diagnostic
establishes a hazardous source-level ordering; a runtime reproducer and
upstream maintainer review are still required to close the kernel finding.
