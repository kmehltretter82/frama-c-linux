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
from 1/21 to 21/21 unmodified Linux translation units reaching a typed AST.
See [KERNEL.md](KERNEL.md#current-measured-status) for the reproducible command,
scope, caveats, and next work.

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
