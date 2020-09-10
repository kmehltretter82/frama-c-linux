# Running qualif tests

- Be sure that you have installed the appropriate versions of
  alt-ergo and coq _before_ having compiled Frama-C.
- use `make wp-qualif` in the toplevel Frama-C directory

# How to add a new test

```
cd src/plugins/wp
git add tests/wp_gallery/find.i
```

## Update oracle for default configuration

1. generate oracle files
```
ptests.opt tests/wp_gallery/find.i -show
ptests.opt tests/wp_gallery/find.i -update
```

2. check again (for a final validation) before adding the oracle files
```
ptests.opt tests/wp_gallery/find.i
git add tests/wp_gallery/oracle/find.*
```

## Update oracle for 'qualif' configuration (if there is such)

1. generate oracle files and updated cache files
```
FRAMAC_WP_CACHE=update ptests.opt -config qualif tests/wp_gallery/find.i -show
ptests.opt -config qualif tests/wp_gallery/find.i -update
```

Note: cleaning the cache is _not_ recommanded when updating or modifying an
existing test; actually it might introduce git merge conflicts that are
annoying to resolve. But the cleaning can be usefull when adding a new test.
It can be done using the command (before those of the step 1):
```
rm -rf tests/wp_gallery/oracle_qualif/find.[0-9]*.session/cache/
```

2. check again (for a final validation) before adding the oracle and cache files
```
ptests.opt -config qualif tests/wp_gallery/find.i
git add tests/wp_gallery/oracle_qualif/find.*
```
