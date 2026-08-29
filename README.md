![Frama-C](share/frama-c.png?raw=true)

> [!NOTE]
> **Frama-C Linux** is a downstream fork focused on accepting Linux kernel C,
> modeling kernel-specific semantics, and finding practical kernel bugs with
> low-noise analyses. It is not an official Frama-C distribution. See the
> [Linux kernel roadmap](KERNEL.md) and the
> [upstream synchronization notes](UPSTREAM.md).

[Frama-C](https://frama-c.com) is a platform dedicated to the analysis of
source code written in C.

## A Collaborative Platform

Frama-C gathers several analysis techniques in a single collaborative
platform, consisting of a **kernel** providing a core set of features
(e.g., a normalized AST for C programs) plus a set of analyzers,
called **plug-ins**. Plug-ins can build upon results computed by other
plug-ins in the platform.

Thanks to this approach, Frama-C provides sophisticated tools, including:
- an analyzer based on abstract interpretation, aimed at verifying
  the absence of run-time errors (**Eva**);
- a program proof framework based on weakest precondition calculus (**WP**);
- a program slicer (**Slicing**);
- a tool for verification of temporal (LTL) properties (**Aoraï**);
- a runtime verification tool (**E-ACSL**);
- several tools for code base exploration and dependency analysis
  (**From**, **Impact**, **Metrics**, **Occurrence**, **Scope**, etc.).

These plug-ins share a common language and can exchange information via
**[ACSL](https://frama-c.com/acsl.html)** (*ANSI/ISO C Specification Language*)
properties. Plug-ins can also collaborate via their APIs.

## Linux kernel corpus

The fork includes `frama-c-script kernel-corpus`, which runs one Frama-C
process per translation unit using exact Kbuild commands and records a
machine-readable failure taxonomy. The initial pinned `x86_64` corpus improved
from 1/21 to 21/21 unmodified Linux translation units reaching a typed AST;
the follow-on DWC3 driver corpus reaches 8/8, and a complete Open vSwitch
`datapath.c` reaches 1/1, for 30/30 across all three `x86_64` sets. The same
21-file library corpus also reaches 21/21 with exact ARM64 Kbuild commands and
the generated `gcc_arm64` machine model. The second target exercises a distinct
ABI, target macros, alignments, and kernel configuration paths; it does not yet
imply complete modeling of ARM64 assembly, atomics, or the architecture memory
model.
See [KERNEL.md](KERNEL.md#current-measured-status) for the reproducible command,
scope, caveats, and next work.

The primary subsystem priority is **ARM64 KVM**. Its first exact-Kbuild corpus
spans 12 host, VGIC, and nVHE translation units. A focused cast-decay fix moves
that corpus from 3/12 to 12/12 typed. The v2 corpus adds all six hyp sources
that Kbuild compiles in both VHE and nVHE contexts. The runner selects each
exact command and isolates it in a one-entry compilation database; all 24
target analyses across 18 distinct source files reach a typed AST. The v3
corpus expands this to the complete pinned Kbuild inventory: 75/75 command
contexts across all 69 ARM64 KVM C files type from unmodified sources. Two
focused fixes initially added GCC 15 counted-by fallback typing and permitted
ordinary local objects named like standard function-like macros.

The v4 gate pins clean Linux `548e7bcd0c54`, adds all eight compiled generic
`virt/kvm` sources, and types 83/83 command contexts across 77 distinct C
files. Revision `d18e6fd3dc` replaces the fallback with real GCC semantics:
Frama-C retains and validates `counted_by` field associations, gives
`__builtin_counted_by_ref` its field-dependent pointer type and address, and
models GCC's unannotated null result without evaluating the operand. The exact
`virt/kvm/irqchip.c` command now normalizes Linux's `kzalloc_flex()` counter
update to the actual `nr_rt_entries` field. Eva itself does not yet use this
metadata as a universal flexible-array invariant, but revision `6e333cae29`
adds a low-noise `kernel-checks` rule that consumes it at Eva-reached reads and
writes. Focused tests report six provable violations and none in safe or mixed
controls. An exact-Kbuild `irqchip.c` scenario reports zero findings on the
real guarded path and one on an explicit harness-only `map[-1]` sensitivity
control. This validates detection and rejects one suspected signed-GSI case;
it is not a new Linux bug finding or a proof of IRQ-routing correctness.

The first bounded semantic replay exercises
the known 2023 `kvm_arm_set_fw_reg()` stack overflow: an Eva user-copy extent
model reports one invalid destination bound for the vulnerable prefix and none
for the current guarded function, both inside the complete current
`hypercalls.c` translation unit. This calibrates bug detection against a
historical fix; it is not a newly discovered kernel bug. Fresh work now applies
the same evidence standard to KVM candidates and architecture-boundary
scenarios.

## Linux kernel checks

The downstream `kernel-checks` plug-in begins the semantic-specialization
layer. Its first rule uses Eva values to report only provable uses of encoded
`ERR_PTR` values as object pointers, indirect call targets, or deallocator
arguments. Focused tests cover 32-bit and 64-bit intervals and common kernel
deallocators; a reduced replay of Linux fix `ee30dd2909d8` reports one
violation before the fix and none after it. A tracked bounded harness now
includes the complete current Open vSwitch `datapath.c`, forces the affected
allocation failure, and reports the same one-before/zero-after result when the
upstream one-line fix is reversed and restored. Enable it with
`-kernel-checks`. See
[the plug-in README](plugins/kernel_checks/README.md) for the reproducible
workflow, guarantees, and limitations.

The same plug-in now also checks direct accesses to retained GCC `counted_by`
flexible-array and counted-pointer fields. It reports only all-invalid Eva
states and leaves mixed or unavailable states inconclusive. Its first full
ARM64 KVM application is the bounded generic IRQ-routing control above; it
found no defect in the tested real-source path.

ARM64 KVM validation also includes a user-copy size model and reduced plus
full-translation-unit replays of Linux fix `a25bc8486f9c0`. A userspace-selected
16-byte register copy into an 8-byte stack object produces one invalid ACSL
precondition before the fix and none after the size guard. This is the first
KVM semantic calibration case, not a fresh finding.

Fresh ARM64 KVM analysis has now moved beyond calibration. A focused MTE
initialization checker reports one current faultable-user-access ordering in
the complete 160-function `guest.c` translation unit. A reduced Eva model also
invalidates the folio-wide MTE validity invariant when KVM initializes only one
base page before publishing a hugetlb folio as tagged, while proving a
whole-folio fixed control. A seven-lens source audit produced five
high-confidence current candidates in total; the initialization-lock and
vCPU validation-order findings are now automated. Runtime reproduction and
Linux maintainer confirmation remain open. The three MTE-family candidates
now have
a [four-patch v1 fix series](contrib/linux-patches/arm64-kvm-mte-v1/): against
Linux `548e7bcd0c54`, the exact Kbuild-mapped checker result changes from one
ordering violation to none, and the affected ARM64 configurations compile with
`W=1`. This remains candidate source and compile evidence, not an upstream
confirmation.

The vCPU-events candidate also has a
[one-patch v1 fix](contrib/linux-patches/arm64-kvm-vcpu-events-v1/). Revision
`50bbaa81fb` adds an exact-Kbuild harness over the complete real `guest.c`.
Baseline Eva proves `KVM_SET_VCPU_EVENTS` returns `-EINVAL` after committing an
external abort and changing PC and PSTATE, making its atomic-rejection
assertion invalid; the complete patched `guest.c` proves both rejection and
unchanged-state assertions. Linux history shows the original external-abort
implementation validated SError first and `77ee70a07357` introduced the
reordering. The patch and ARM64 selftest cross-build cleanly and pass strict
`checkpatch`, but have not yet been executed on ARM64 hardware or accepted
upstream.

Revision `3d8d9df6a6` generalizes that custom assertion into a low-noise
validation-order checker. It tracks state writes through defined direct-call
chains, follows request-derived conditions, and reports an immediate
`-EINVAL` only after a proved earlier mutation. The new
`-kernel-checks-ast-only` profile scans translation units without requiring an
Eva entry point. Across all 83 exact ARM64 and generic KVM v4 command contexts,
83/83 type and exactly one diagnostic remains: the same
`__kvm_arm_vcpu_set_events()` candidate. The candidate fixed `guest.c` produces
zero. This automates and broadens detection; runtime and maintainer confirmation
are still required before counting a confirmed Linux bug.

## Installation

Installation packages for Linux and macOS are available on
[Frama-C's website](https://www.frama-c.com/html/get-frama-c.html).

Frama-C is developed mainly in Linux, often tested in macOS
(via Homebrew), and occasionally tested on Windows
(via the Windows Subsystem for Linux).

Other installation methods are available, see [INSTALL.md](INSTALL.md).

### Development branch

To install the development branch of Frama-C (updated nightly), one should use
[Opam](https://opam.ocaml.org/):

    opam pin add frama-c --dev-repo

This command will *pin* the development version of Frama-C and try to install it.
If installation fails due to missing external dependencies, try using
the same commands from the [Installation](#installation) section to get the
external dependencies and then install Frama-C.

### Distribution packages

Some Linux distributions have a `frama-c` package, kindly provided by
distribution packagers. Note that they may not correspond to the latest
Frama-C release.

## Usage

Frama-C can be run from the command-line, or via its graphical interface.

#### Simple usage

The recommended usage for simple files is one of the following lines:

    frama-c file.c -<plugin> [options]
    frama-c-gui file.c -<plugin> [options]

Where `-<plugin>` is one of the several Frama-C plug-ins,
e.g. `-eva`, or `-wp`, or `-metrics`, etc.
Plug-ins can also be run directly from the graphical interface.

To list all plug-ins, run:

    frama-c -plugins

Each plug-in has a help command
(`-<plugin>-help` or `-<plugin>-h`) that describes its own
options.

Finally, the list of options governing the behavior of Frama-C's kernel itself
is available through

    frama-c -kernel-help

#### Complex scenarios

For complex usage scenarios (several files and directories,
preprocessing directives, etc), we recommend the following two-step approach:

1. Parsing the input files and saving the result to a file;
2. Loading the parsing results and then running the analyses or the GUI.

Parsing complex C applications usually involves C preprocessor options
(e.g. GCC's `-D` and `-I`).
In Frama-C, they are passed via option `-cpp-extra-args`, as in this example:

    frama-c *.c -cpp-extra-args="-D<define> -I<include>" -save parsed.sav

The results can then be loaded into Frama-C for further analyses or for inspection
via the GUI:

    frama-c -load parsed.sav -<plugin> [options]
    frama-c-gui -load parsed.sav -<plugin> [options]

## Further reference

- Links to user and developer manuals, Frama-C archives,
  and plug-in manuals are available at <br> https://frama-c.com/html/get-frama-c.html

- The [Frama-C documentation page](https://frama-c.com/html/documentation.html)
  contains links to all manuals and plugins description, as well as tutorials,
  courses and more.

- [StackOverflow](https://stackoverflow.com/questions/tagged/frama-c) has several
  questions with the `frama-c` tag, which is monitored by several members of the
  Frama-C community.

- The [Frama-c-discuss mailing list](https://groupes.renater.fr/sympa/info/frama-c-discuss)
  is used for announcements and general discussions.

- The [Frama-C blog](https://frama-c.com/blog) has several posts about
  new developments of Frama-C, as well as general discussions about the C
  language, undefined behavior, floating-point computations, etc.

- The [Frama-C public repository](https://git.frama-c.com/pub/frama-c)
  contains a daily snapshot of the development version of Frama-C, as well as
  the [issues tracking system](https://git.frama-c.com/pub/frama-c/issues),
  for reporting bugs.
  These [contribution guidelines](CONTRIBUTING.md) detail how to submit
  issues or create merge requests.
