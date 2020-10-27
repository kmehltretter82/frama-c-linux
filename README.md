![Frama-C](share/frama-c.png?raw=true)

[Frama-C](http://frama-c.com) is a platform dedicated to the analysis of
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
**[ACSL](http://frama-c.com/acsl.html)** (*ANSI/ISO C Specification Language*)
properties. Plug-ins can also collaborate via their APIs.

## Installation

For more detailed information about installing opam/Frama-C,
see [INSTALL.md](INSTALL.md).

Frama-C is available through [opam](http://opam.ocaml.org/), the
OCaml package manager. This is the preferred installation method. Be sure
to install opam v2.0 or higher. Then the following sequence of commands
should install frama-c and its gui:

    opam init
    opam install depext
    opam depext frama-c
    opam install frama-c

Frama-C is developed mainly in Linux, often tested in macOS
(via Homebrew), and occasionally tested on Windows
(via the Windows Subsystem for Linux).

## Usage

Frama-C can be run from the command-line, or via its graphical interface.

#### Simple usage

The recommended usage for simple files is one of the following lines:

    frama-c file.c -<plugin> [options]
    frama-c-gui file.c

Where `-<plugin>` is one of the several Frama-C plug-ins,
e.g. `-eva`, or `-wp`, or `-metrics`, etc.
Plug-ins can also be run directly from the GUI.

To list all plug-ins, run:

    frama-c -plugins

Each plug-in has a help command
(`-<plugin>-help` or `-<plugin>-h`) that describes its several
options.

Finally, the list of options governing the behavior of Frama-C's kernel itself
is available through

    frama-c -kernel-help

#### Complex scenarios

For more complex usage scenarios (lots of files and directories,
with several preprocessing directives), we recommend splitting Frama-C's usage
in two parts:

1. Parsing the input files and saving the result to a file;
2. Loading the parsing results and then running the analyses or the GUI.

Parsing typically involves giving extra arguments to the C preprocessor,
so the `-cpp-extra-args` option is often useful, as in the example below:

    frama-c *.c *.h -cpp-extra-args="-D<define> -I<include>" -save parsed.sav

The results are then loaded into Frama-C for further analyses or for inspection
via the GUI:

    frama-c -load parsed.sav -<plugin> [options]
    frama-c-gui -load parsed.sav -<plugin> [options]

## Further reference

- Links to user and developer manuals, Frama-C archives,
  and plug-in manuals are available at <br> http://beta.frama-c.com/html/get-frama-c.html

- [StackOverflow](http://stackoverflow.com/questions/tagged/frama-c) has several
  questions with the `frama-c` tag, which is monitored by several members of the
  Frama-C community.

- The [Frama-c-discuss mailing list](http://lists.gforge.inria.fr/cgi-bin/mailman/listinfo/frama-c-discuss)
  is used for announcements and general discussions.

- The [Frama-C public repository](https://git.frama-c.com/pub/frama-c)
  contains a daily snapshot of the development version of Frama-C, as well as
  the [issues tracking system](https://git.frama-c.com/pub/frama-c/issues),
  for reporting bugs.

- The [Frama-C documentation page](https://beta.frama-c.com/html/documentation.html)
  contains links to all manuals and plugins description, as well as tutorials, courses
	and more.

- The [Frama-C blog](http://beta.frama-c.com/blog) has several posts about
  new developments of Frama-C, as well as general discussions about the C
  language, undefined behavior, floating-point computations, etc.
