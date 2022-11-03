# Aoraï usage example

This directory contains 2 examples:

## Example 1 (with many goto)

### Files

- `example.c`: program to check
- `example.ya`: YA automaton

### Usage

The following commands generates the `example_annot.c` file containing the instrumented code

```sh
frama-c example.c -aorai-automata example.ya -then-last -ocode example_annot.c -print
```

File `example.ya` is the automaton that describes the sequences of function calls that are allowed for the program.

In order to decide if the original program is correct wrt this automaton, it is sufficient to establish than the generated C is valid with respect to the generated ACSL annotations.
For instance, with the WP plugin:

```sh
frama-c example_annot.c -wp
```

It is also possible to run Aoraï and WP in a single Frama-C run with

```sh
frama-c example.c -aorai-automata example.ya -then-last -wp
```

## Example 2 (with a loop)

### Files

- `example_loop.c`: program to check
- `example_loop.ya`: YA automaton

### Usage

The following command generates the `example_loop_annot.c` file

```sh
frama-c example_loop.c -aorai-automata example_loop.ya -then-last -ocode example_loop_annot.c file
```

In order to decide if the original program is correct wrt the property, it is sufficient to establish than the generated C is valid. For instance, with the WP plugin:

```sh
frama-c example_loop_annot.c  -wp
```

Again, it is possible to run Aoraï and WP in a single Frama-C run:

```sh
frama-c example_loop.c -aorai-automata example_loop.ya -then-last -wp
```
