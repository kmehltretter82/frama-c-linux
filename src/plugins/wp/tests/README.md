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

1. update the cache
```
git -C src/plugins/wp/cache pull --rebase --prune
```

2. generate oracle files and updated cache files
```
FRAMAC_WP_CACHE=update ptests.opt -config qualif tests/wp_gallery/find.i -show
ptests.opt -config qualif tests/wp_gallery/find.i -update
```

3. publish the new cache
```
git -C src/plugins/wp/cache add -A
git -C src/plugins/wp/cache commit -m "[wp] cache updates"
git -C src/plugins/wp/cache push -f
```

## Using Makefile

```
make wp-qualif           # Run qualif tests (clone cache if necessary)
make wp-qualif-update    # Run with cache updates (git access)
make wp-qualif-push      # Push cache updates (git access)
make wp-qualif-cleanup   # Remove old cache entries (no access since 2h)
```
