# Frama-C Linux

Frama-C Linux is a fork of Frama-C aimed at useful static verification of
production Linux kernel code. The fork may change Frama-C's parser, kernel,
plug-ins, and command-line tooling where that produces a cleaner result. There
is no project rule that the Frama-C core must remain untouched.

The long-term objective is not to "prove all of Linux." It is to make
Frama-C usable on increasingly large, unmodified kernel translation units,
give its analyses an accurate model of important kernel conventions, and turn
that foundation into actionable bug reports.

## First goal: kernel translation-unit compatibility

The first milestone is an end-to-end path from a real Kbuild compile command to
a typed Frama-C AST. A source file counts as supported only when its original
kernel source and headers are left unmodified.

The milestone is complete when the project can:

1. consume a translation unit and its flags from Kbuild-generated
   `compile_commands.json`;
2. preserve the relevant `-D`, include, forced-include, target, and language
   options rather than reconstructing them by hand;
3. preprocess, parse, type-check, and normalize the complete function bodies;
4. represent unsupported inline assembly conservatively instead of silently
   deleting its effects;
5. report failures by stage and construct in a machine-readable form; and
6. run a versioned corpus as regression tests and publish its success rate.

The initial corpus should stay small enough to diagnose every failure. It will
start with architecture-neutral library code and `drivers/usb/dwc3`, then grow
across subsystems and architectures. Host `x86_64` is the first front-end
target; `arm64` is now the second measured target. ARM64 KVM is the primary
next subsystem, with RISC-V and broader subsystem coverage following it.

Compatibility work will initially concentrate on constructs that occur in
kernel builds, including:

- GNU C and newer compiler syntax such as `__auto_type`, `typeof_unqual`,
  statement expressions, local labels, computed gotos, and GNU variadic
  macros;
- kernel and compiler attributes, address spaces, vector types, flexible and
  zero-length arrays, and target-specific built-ins;
- inline `asm`, `asm goto`, constraints, clobbers, and architecture-specific
  register conventions; and
- generated headers and compiler feature probes selected by Kbuild.

Passing the parser is not sufficient if a workaround changes program meaning.
Every compatibility rule therefore needs a focused regression test and an
explicit semantics policy.

## Current measured status

Three versioned `x86_64` corpora are pinned to Linux commit
`388b607d107c07aaade04c7f22f344cab6bdccd3` and GCC 15.2.0:

- `linux-x86_64-v1` contains 21 architecture-neutral MPI and string-library
  translation units from a `tinyconfig` build; and
- `linux-x86_64-dwc3-v1` contains eight DWC3 core, dual-role, gadget, host,
  tracing, ULPI, and debugfs translation units from its supplied Kconfig
  fragment; and
- `linux-x86_64-openvswitch-v1` contains the complete Open vSwitch
  `net/openvswitch/datapath.c` translation unit from its supplied Kconfig
  fragment.

The versioned `linux-arm64-v1` corpus runs the same 21 architecture-neutral
library files through an ARM64 `tinyconfig` Kbuild with
`aarch64-linux-gnu-gcc` 15.2.0. This is a distinct target/ABI measurement, not
21 additional unique source files. It matters because data-model details,
target predefined macros, alignment, and Kconfig-selected paths can differ
from x86_64 even for common C files. It is frontend coverage, not yet a claim
that ARM64 inline assembly, atomics, PAC/MTE, or the architecture memory model
have complete verification semantics.

On 2026-08-28, all 30 `x86_64` translation units and all 21 ARM64 target runs
reached a typed AST from unmodified kernel sources and headers:

| Front-end revision | Corpus | Typed | First blocking failure |
| --- | --- | ---: | --- |
| `ba238b329d8e9201ae28813281d2549d73192bdb` | library | 1/21 | 20 non-constant static assertions |
| `c0dceb9138348f5fe04c53c8c553dfefcd96010e` | library | 21/21 | none |
| `52d9f1ec9ee800f8ff2708d3c5665199659b7f31` | library | 21/21 | none |
| `52d9f1ec9ee800f8ff2708d3c5665199659b7f31` | DWC3 | 8/8 | none |
| `880d8ef6f5b4269b59db60c88e874ab026cf681c` | library | 21/21 | none |
| `880d8ef6f5b4269b59db60c88e874ab026cf681c` | DWC3 | 8/8 | none |
| `1fea1525b664a1475b04f90b896914ae18563538` | library | 21/21 | none |
| `1fea1525b664a1475b04f90b896914ae18563538` | DWC3 | 8/8 | none |
| `543de713a19da4be6128b93c2fd27c4b28276a03` | library | 21/21 | none |
| `543de713a19da4be6128b93c2fd27c4b28276a03` | DWC3 | 8/8 | none |
| `3f28ad0641bf27835b0f7b87c3925704491a740a` | library | 21/21 | none |
| `3f28ad0641bf27835b0f7b87c3925704491a740a` | DWC3 | 8/8 | none |
| `af35b39cf375e0e21681c2d62f3e088ae869a80b` | Open vSwitch datapath | 1/1 | none |
| `beea50c48973af68920d96ad225483a2fd26d26c` | ARM64 library | 21/21 | none |

Revision `52d9f1ec9e` adds a force-included kernel compiler model for the
`clz`/`ctz` builtin families and fixes GNU `void` conditional expressions used
by the kernel delay macros. On the 21-file corpus, enabling the model on the
same revision reduces implicit-function-declaration warnings from 147 to 63
and total warnings from 5,648 to 5,564. Revision `880d8ef6f5` adds typed ACSL
contracts for matching signed and unsigned add, subtract, and multiply
overflow builtins. Together, the models eliminate all 147 undeclared-builtin
warnings in the 21-file corpus and all 24 in DWC3, reducing the respective
warning totals to 5,501 and 2,892. Revision `1fea1525b6` then fixes partial
`const`/`volatile` qualifier additions in general C type compatibility. It
removes 2,160 spurious call-type warnings from the library corpus and 1,136
from DWC3, reducing the totals again to 3,341 and 1,756 while preserving
warnings for qualifier removal. Revision `543de713a1` preserves the argument
type of polymorphic `__builtin_constant_p` expressions instead of casting them
through its placeholder `int` prototype. This removes another 680 warnings
from the library corpus and 320 from DWC3, leaving totals of 2,661 and 1,436.
Revision `3f28ad0641` classifies GCC `hot` and `cold` as function-type
attributes while continuing to preserve them on labels. This removes 2,062
misplaced-attribute warnings from the library corpus and 1,024 from DWC3,
leaving 599 and 412 warnings respectively. The remaining attribute warnings
are explicitly identified unknown attributes rather than silently discarded
declaration attributes.

Revision `af35b39cf3` takes the unmodified Open vSwitch datapath through a
typed AST by adding four focused kernel-C compatibility rules: trailing
commas in extended-asm operand lists, GNU omitted-middle conditionals inside
attributes, constant folding for the `__builtin_bswap16`/`32`/`64` families,
and GCC/MSVC nested flexible-array extensions. Strict machine models continue
to reject the latter extension. The resulting translation unit contains 241
defined functions, 3,747 source lines, 813 calls, and 864 pointer
dereferences. It emits 64 classified warnings and no undeclared builtins.

Revision `beea50c489` adds reproducible GCC ARM64 support. The machdep
generator now distinguishes the semantic compiler family (`gcc`) from the
cross-compiler executable and retains both for byte-identical `--from-file`
regeneration. The generated LP64 model exposes AArch64 target macros,
unsigned plain `char`, 128-bit integer support, and target alignments. The
kernel-safe compiler header supplies GCC's predefined `__int128_t` and
`__uint128_t` aliases, and the front end preserves constant conditional
operands while folding nonzero `clz`/`ctz` builtin families with machdep-sized
widths.

Those changes move the ARM64 corpus from 0/21 syntax failures, through 0/21
typing failures and 1/21 typed, to 21/21 typed. The final run contains 132
defined functions, 3,952 source lines, 320 calls, and 614 pointer
dereferences, with 993 classified warnings and no undeclared builtins. ARM64
`tinyconfig` enables SMP with 512 configured CPUs, exposing the constant
`ilog2` array-bound path that the initial x86 configuration did not exercise.

The measurements used clean Linux sources. The library compilation database
was copied from Kbuild with only its absolute source-root prefix relocated;
the DWC3, Open vSwitch, and ARM64 databases were generated directly in
out-of-tree builds. Reproduction metadata and warning inventories are in
[`linux-x86_64-v1.status.json`](share/kernel-corpus/linux-x86_64-v1.status.json)
and
[`linux-x86_64-dwc3-v1.status.json`](share/kernel-corpus/linux-x86_64-dwc3-v1.status.json),
with frontend and checker evidence for Open vSwitch in
[`linux-x86_64-openvswitch-v1.status.json`](share/kernel-corpus/linux-x86_64-openvswitch-v1.status.json)
and ARM64 frontend evidence in
[`linux-arm64-v1.status.json`](share/kernel-corpus/linux-arm64-v1.status.json).

Run the corpus against a matching kernel checkout with:

```sh
frama-c-script kernel-corpus \
  --compilation-database /path/to/compile_commands.json \
  --kernel-root /path/to/linux \
  --corpus "$(frama-c -print-share-path)/kernel-corpus/linux-x86_64-v1.json" \
  --jobs 4 \
  --require-all-typed \
  --output results.json
```

Use `linux-x86_64-dwc3-v1.json` or `linux-x86_64-openvswitch-v1.json` in the
command above with a compilation database generated from the matching
fragment in `configs/`. Corpus manifests automatically load their declared
model headers; pass `--no-manifest-models` for a controlled unmodeled
comparison.

For ARM64, use `linux-arm64-v1.json`, an ARM64 `tinyconfig` compilation
database, and add `--machdep gcc_arm64`. The compiler executable recorded in
the machdep is generation and round-trip metadata; target preprocessing flags
still come from the selected compilation-database entry.

From this repository's development tree, build `@install` and replace the
command above with
`opam exec --switch=fragma -- dune exec --no-build -- frama-c-script`.
The runner executes one Frama-C process per translation unit, saves full logs,
and writes the exact compiler and Frama-C commands, first terminal diagnostic,
failure stage and kind, warning keys, missing built-ins, unknown attributes,
timings, and Metrics output to JSON.

This 100% result establishes front-end compatibility for these small corpora;
it does **not** establish that the files are bug-free or that every kernel
operation is modeled accurately. The runs still expose a semantic-quality
queue, notably pointer and call-type warnings, unsupported attributes,
library-model warnings, dropped side effects in unevaluated `sizeof`
operands, and conservative inline-assembly handling. Those models and
diagnostics must improve before a typed AST is treated as a verification
result.

## Priority target: ARM64 KVM

ARM64 KVM is the primary next expansion target. It is both architecture-heavy
and security-sensitive: host EL1 code controls guest state, while VHE, nVHE,
and protected-KVM code crosses the EL2 privilege boundary and manages stage-2
translation and memory ownership. This makes it a useful test of whether the
fork can progress from portable kernel C to architecture-specific bug finding.

The existing 21/21 ARM64 corpus is only a prerequisite. It validates the GCC
AArch64 machine model and common C frontend paths, but contains no KVM
translation units. ARM64 KVM work will proceed in measured layers:

1. generate a KVM-enabled ARM64 build and version an exact-Kbuild corpus across
   representative host code, stage-2 page-table code, VGIC/sysreg emulation,
   and nVHE/pKVM C code;
2. classify frontend blockers without modifying Linux sources, adding focused
   tests for every accepted compiler or architecture extension;
3. model system-register accesses, privileged assembly boundaries, barriers,
   atomics, locks, address translation, and page ownership conservatively;
4. add bounded scenarios for stage-2 map/unmap, vCPU/sysreg handling, MMIO,
   allocation cleanup, and protected-KVM ownership transitions; and
5. validate candidate checkers against real historical ARM64 KVM fixes, with
   positive findings, fixed controls, coverage, alarms, and model assumptions
   recorded separately.

Initial success means reproducible C analysis and defensible findings on
selected paths. It does not mean proving the complete KVM implementation, the
Arm memory model, or handwritten assembly. Unsupported EL2 effects must remain
visible and conservative rather than being silently erased.

## Architecture

The intended data flow is:

```text
Kbuild compile database
        |
        v
command adapter --> GNU/kernel-C front end --> typed Frama-C AST
                                                   |
                         +-------------------------+------------------+
                         |                         |                  |
                         v                         v                  v
                 kernel models               Eva / WP          kernel checkers
                         \_________________________|__________________/
                                                   |
                                                   v
                                      diagnostics + SARIF + metrics
```

Changes belong at the layer that owns the behavior:

- generally useful GNU C support should be implemented in the Frama-C front
  end and proposed upstream where practical;
- Kbuild command translation belongs in dedicated tooling;
- kernel APIs and execution rules belong in a kernel semantic-model layer; and
- bug policies belong in kernel-specific analyses, which can reuse Eva, WP,
  slicing, and the Frama-C property database.

This is a fork-first design: a change is not rejected merely because it touches
the core. Keeping concerns separated is still important so that fixes remain
testable and upstreamable.

## Kernel semantic specialization

After a translation unit parses, analyses need to understand conventions that
ordinary ISO C tools do not. The first semantic model set will cover:

- allocation, ownership, cleanup, reference counting, and devres;
- `ERR_PTR`, `PTR_ERR`, `IS_ERR`, and related tagged-pointer protocols;
- locks, interrupt state, preemption, sleepability, and execution context;
- atomics, barriers, `READ_ONCE`, `WRITE_ONCE`, and conservative inline-asm
  effects;
- RCU publication and read-side critical sections;
- user pointers and `copy_to_user`/`copy_from_user` boundaries;
- intrusive lists, container recovery, callbacks, and common iterator macros;
  and
- the compiler semantics selected by kernel flags, including behavior that
  differs from a strict ISO C undefined-behavior model.

Models must state what they guarantee and what they approximate. An unknown or
unsupported operation should degrade precision visibly, not be treated as a
no-op.

## First bug analyses

The first checker should target the `ERR_PTR` protocol because it has explicit
kernel idioms and admits strong local validation. It should distinguish a
valid object pointer, an encoded error, `NULL`, and an unknown pointer, then
flag only provable protocol violations such as dereferencing or freeing an
encoded error.

Revision `29cce175b1` implements that initial checker as the optional
`kernel-checks` plug-in. It classifies Eva values at reads, writes, indirect
calls, and common deallocator calls, while leaving mixtures and unknown values
unreported. Focused 32-bit and 64-bit tests pass, and a reduced replay of Linux
commit `ee30dd2909d8b98619f4341c70ec8dc8e155ab02` reports one violation before
the Open vSwitch fix and zero after it.

A direct run from `ovs_flow_cmd_set` on the complete current translation unit
exits successfully but reaches only 4 of 241 defined functions and 13 of 104
entry-reachable statements before argument-validity alarms eliminate the
important paths. Deeper generic Eva context initialization exceeded 150- and
180-second limits. Its zero checker findings are therefore explicitly
inconclusive.

The next semantic milestone is now implemented as an opt-in, bounded analysis
scenario. `frama-c-script kernel-harness` maps the exact Kbuild command for a
translation unit onto a small tracked harness, while
`-kernel-checks-bounded-entry` selects a finite Eva callback-entry profile and
`-kernel-checks-err-ptr-source` forces a named pointer-returning operation to
return a chosen encoded error. The Open vSwitch harness includes the complete
`datapath.c`, constructs concrete `sk_buff`, socket, netlink, and attribute
objects, and models the API outcomes needed to reach the allocation-failure
cleanup path.

Against Linux `388b607d107c`, the fixed file analyzes 30 of 251 functions and
reaches 145 of 232 statements in the selected scenario, with two unrelated Eva
alarms and zero `ERR_PTR` findings. Reversing only the one-line change from
`ee30dd2909d8` analyzes the same 30 functions and reaches 144 of 231
statements, with the same two alarms and exactly one finding at
`kfree_skb(reply)`. The allocation function is deliberately fault-injected and
several API success outcomes are scenario models. This is evidence that the
checker exposes the historical defect under the stated failure path; it is not
a proof of the complete translation unit or a general model of Open vSwitch.
Broader automatic entry-state, allocation, ownership, locking, and netlink
models remain required.

The next candidates are:

1. lock and execution-context mistakes, including sleeping in atomic context;
2. resource, cleanup, and reference-count imbalances; and
3. size/range errors at allocation, copy, and user-access boundaries.

Each checker needs positive tests, negative controls, and replay against real
historical kernel fixes before its diagnostics are treated as useful.

## Measurement

Progress will be reported with reproducible numbers rather than selected
examples:

- translation units attempted and successfully typed;
- failures grouped into preprocessing, syntax, typing, normalization, missing
  model, analysis, timeout, and internal-error classes;
- functions and statements retained in the AST;
- analysis coverage, alarms, and reasons for precision loss; and
- true, false, duplicate, and inconclusive results on the validation corpus.

Early success means a rising clean-parse rate and a small number of defensible
findings. Whole-kernel analysis, exact semantics for every architecture's
assembly, and full functional verification are deliberately not requirements
for the first milestone.

## Near-term sequence

1. Keep the fork continuously buildable and the corpus runner reproducible.
   This is established for the current branch and remains a continuous gate.
2. Import exact Kbuild commands and record a baseline failure taxonomy. This
   is established for all four current corpus configurations.
3. Fix the highest-frequency front-end blockers with regression tests. This
   is complete for the current 51 translation-unit/architecture runs and
   continues as the corpus expands.
4. Introduce kernel compiler-semantics and API models. Compiler builtin models
   are in place; object, ownership, concurrency, and architecture models are
   ongoing.
5. Implement and validate the `ERR_PTR` checker. The first rule and historical
   replay are complete, including a tracked bounded scenario over the complete
   Open vSwitch translation unit. General entry and kernel API modeling remain.
6. Expand next into ARM64 KVM without relaxing the unmodified-source rule,
   first measuring representative host and hypervisor C files and then adding
   bounded bug scenarios. RISC-V and broader subsystem coverage follow.
