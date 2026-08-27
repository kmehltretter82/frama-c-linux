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
target; `arm64` and RISC-V follow once the measurement harness is stable.

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

1. Keep the fork continuously buildable and establish the corpus runner.
2. Import exact Kbuild commands and record a baseline failure taxonomy.
3. Fix the highest-frequency front-end blockers with regression tests.
4. Introduce kernel compiler-semantics and API models.
5. Implement and validate the `ERR_PTR` checker.
6. Expand the corpus by subsystem and architecture without relaxing the
   unmodified-source rule.
