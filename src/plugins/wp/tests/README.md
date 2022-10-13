# Audience

This manual is _only_ intended for Frama-C developers who need to execute tests
that are using WP with external provers.

## WP Tests Configurations

There are two configurations for WP tests:
- the default configuration, which does not use external provers
- the `qualif` configuration, which _does_ use external provers

It is highly recommended to use the `./bin/test.sh` wrapper for executing WP tests.
See section "WP Tests Recipes" below for details.

Advanced users and Frama-C developers might consider managing the cache on
their own.
See section "Advanced Cache Management".

## WP Tests Recipes

When using the `./bin/test.sh` test wrapper, you don't need to configure the
environment variables mentioned below: the script automatically manages them for you.

Before executing WP tests in qualif configuration, you shall initiate the WP-cache.
This is done automatically by:

    $ ./bin/test.sh -p

The first time it is executed, it will clone the `wp-cache` Git repository in `./.wp-cache`.
The following times, this same command will automatically pull the latest cache entries.

You check tests are up-to-date with:

    $ ./bin/tests.sh src/plugins/wp/tests

When a test complains that a test result is missing from wp-cache, simply re-run
the desired tests in "update" mode:

    $ ./bin/tests.sh src/plugins/wp/tests/… -u

If necessary, you may `dune promote` the new oracles and, correspondingly,
you may `git commit` the new cache entries from `./.wp-cache` directory.

## Advanced Cache Management

It is possible to share the wp-cache repository among different plug-ins.
`./bin/test.sh` uses, in order of proprity:
- `FRAMAC_WP_QUALIF` environment variable,
- `FRAMAC_WP_CACHEDIR` environment variable,
- local `./.wp-cache` directory.

Of course, these environment variables must be set to an absolute path since test executions are done from different directories.

It is _not_ recommended to use the `FRAMAC_WP_CACHEDIR` variable in your default
shell setup, unless is it a temporary directory (eg. `/tmp/wp-sandbox`) since
_every_ run of `frama-c -wp` might then use it by default. Be careful if you do so.

However, it is _highly_ recommended for frama-c developers to export the
`FRAMAC_WP_QUALIF` variable in their default shell setup.
