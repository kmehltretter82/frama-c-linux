# Ensuresec

This folder illustrates the developments done for the European H2020 project
Ensuresec.

## Files

### `Makefile`

The makefile in the folder provides some targets to test the ensuresec
developments:

- `compile` (default): Compile `ensuresec_ee.c` with the external assert
  implementation in `json_assert.c`.
- `compile_print_all`: Same as `compile` but every assertion (valid or invalid)
  will be printed to the output.
- `compile_debug`: Same as `compile_print_all` but in debug mode.
- `run`: run the output of the `compile` step.
- `run_print_all`: run the output of the `compile_print_all` step.
- `run_debug`: run the output of the `compile_debug` step.

### `json_assert.c`

The file `json_assert.c` contains an external `__e_acsl_assert()` implementation
that will print assertion violations to a json file.

The following environment variables must be defined when using this
implementation:

- `ENSURESEC_EE_ID`: Ensuresec e-commerce ecosystem id
- `ENSURESEC_EE_TOOL_ID`: Ensuresec e-commerce ecosystem tool id
- `ENSURESEC_OUTPUT_FILE`: json output file

### `ensuresec_ee.c`

Multithread program serving as an exemple Ensuresec e-commerce ecosystem
program. The program contains `check` assertions that will be violated during
its execution without halting the program.
