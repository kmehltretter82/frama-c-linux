# Crowbar tests

This folder regroup some tests using the OCaml library Crowbar.
To run these tests the environment variable `CROWBAR` must be defined :

```bash
CROWBAR= dune test tests/crowbar
```

If `CROWBAR` is defined, these tests can also be run using `dune build
@runtest`.
