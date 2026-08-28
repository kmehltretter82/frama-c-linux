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

## Validation and scope

Focused tests cover the error-interval boundaries, mixed/unknown values,
32-bit and 64-bit machine models, configurable `MAX_ERRNO`, reads, writes,
indirect calls, and both first- and second-argument deallocators. A reduced
replay of Linux commit `ee30dd2909d8b98619f4341c70ec8dc8e155ab02`
(`net: openvswitch: fix possible kfree_skb of ERR_PTR`) reports one provable
violation before the fix and none after it.

This establishes the checker rule, not whole-kernel analysis coverage. On an
unmodified Open vSwitch `datapath.c`, the frontend reaches a complete typed
AST, but Eva still needs kernel object and API models to construct a precise
entry state and follow the relevant call paths. A zero checker count from such
a shallow run must therefore be treated as inconclusive rather than as proof
that the translation unit is free of `ERR_PTR` misuse.
