# May-Alias Analysis plugin

Alias is a Frama-C plugin that implements:
- a points-to analysis, i.e. an over-approximation of the possible values a
  pointer may point to at run-time.
- a may-alias analysis, i.e. an over-approximation of the possible aliases
  between pointer variables (and, more generally, memory regions) of the
  program.

Two pointers are called aliases of each other if they point at runtime to the
same memory location. In that case changing the value of one pointer also
changes the value of the other pointer and vice versa.

The plugin implements a variant of « Steensgaard's algorithm ».

Note that the Eva plugin also implements a points-to analysis, which is much
more precise but also much less efficient than this plugin.

## Usage

To run the may-alias analysis either:
- call the function `Alias.Analysis.compute`
- run `frama-c` with the `-alias` flag

Please run `frama-c -alias-h` for more information on command-line flags.

## API

`Alias.Analysis` provides functions to run the analysis and clear the analysis
results.
The module `Alias.API` provides function to access the analysis results.

## Limitations

This plugin implements a path-insensitive analysis based on purely syntactic
reasoning, with out numerical domains/values computations. When some branch
condition appears in the program, any alias in any branch is considered.
Therefore the analysis is efficient, whereas the results are not very precise.

### Unsupported constructs
- recursive functions
- user-defined variadic functions
- function declared and used without being defined (i.e., no function body)
- function pointers
- assembly code
- instructions longjmp and setjmp
- complex instruction goto that breaks the natural control-flow of the program
- heterogeneous casts (e.g., casts from integers to pointers or conversely)
- union type
- dynamic memory allocation, except if done once at the beginning of the
  program, whichever the execution path is.

### Imprecisely-supported constructs
- non-complex instruction goto
- homogeneous casts
- recursive datatype, e.g., multiple levels of pointer dereferencing
- pointer arithmetic, and array and structure accesses
- variable-length arrays
- volatile attributes

## Building and Installation

The plug-in is included by default when installing Frama-C.

To build the and install the plugin with profiling install the package
landmarks-ppx and run:
1. `dune build --instrument-with landmarks`
2. `dune install --instrument-with landmarks`
The plugin will then echo profiling information to stderr.

Note that this plugin uses assertions extensively, which has considerable
performance cost. Building and installing using the `--release` flag disables
these assertions.

## Project Members

Allan Blanchard
Loïc Correnson
Tristan Le Gall
Jan Rochel
Julien Signoles
