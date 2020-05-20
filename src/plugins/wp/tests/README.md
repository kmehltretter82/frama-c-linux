# Test Suites

Here is a short description of the WP tests suites:

- `tests/wp` tests dedicated to the VC generation engine and proof strategy
- `tests/wp_tip` tests associated to the script engine
- `tests/wp_acsl` tests of generic C/ACSL concepts
- `tests/wp_typed` tests dedicated to aliasing memory model
- `tests/wp_hoare` tests dedicated to non-aliasing memory model
- `tests/wp_region` tests dedicated to region memory model
- `tests/wp_manual` tests for generating the examples of the reference manual
- `tests/wp_gallery` non-regression tests for representative real size usage of WP
- `tests/wp_plugin` general purpose WP plug-in options
- `tests/wp_bts` non-regression tests associated to GitLab issues; eg. `issue_xxx.i`

Deprecated test suites that shall be moved around:

- `tests/wp_usage` mostly movable to `tests/wp_plugin`
- `tests/wp_store` mostly movable to `tests/wp_typed`

# Test Configurations

There are two tests configurations:
- the default one requires _no_ prover execution;
- the `qualif` configuration uses the `wp-cache` global cache, `Alt-Ergo` and `Coq`.

The test configurations `tests/test_config` and `tests/test_config_qualif` are
carefully crafted to fit with the constraints associated to the GitLab
Continuous Integration system. In particular, the `qualif` configuration is
designed for being used with a local clone of the global WP cache, see
installation instruction below.

To re-run tests, use by default the following commands:
- `make Wp_TESTS` for the default test configuration;
- `make wp-qualif` for the `qualif` configuration;

When using the `wp-qualif` target, it wil clone the global wp-cache at `../wp-cache` by default,
if not yet present. To choose another place, consult the « Global WP Cache » section below.
The WP makefile provides several targets to automate the cache management. It is highly
recommanded to use them most of the time:

- `make wp-qualif` re-run qualif tests; no new cache entry is created, though.
- `make wp-qualif-update` re-run and create missing cache entries.
- `make wp-qualif-upgrade` create missing cache entries _and_ update tests scripts is necessary.
- `make wp-qualif-push` commits and push all new cache entries to the GitLab repo.
- `make wp-qualif-status` display a very short git status of your local clone of wp-cache.

To execute a given test by hand in `qualif` configuration, do the following
in a local shell:

    $ export FRAMAC_WP_CACHE=update
    $ export FRAMAC_WP_CACHEDIR=<absolute-dir-to-wp-cache>
    $ ./bin/ptests.opt src/plugins/wp/tests/xxx/yyy.i [-show|-update]

It is _not_ recommanded to set the `FRAMAC_WP_xxx` variables globally, to avoid
adding new cache entries that are non-related to the WP test suite. Consult
the section « Global WP Cache Setup » below for details.

# Global WP Cache Setup (for wp-qualif)

All prover results for test configuration `qualif` shall be cached in a dedicate GitLab repo.
This considerally speed-up the process of running those tests, from hours downto minutes.

To ease the management of cache entries accross different Frama-C branches,
_all_ cache entries are merged into the _same_ master branch of a global
repository. This strategy prevents merge conflicts related to different cache
entries and simplifies the review of MR, especially those modifying the VC
generation process. The gitLab Frama-CI continuous integration system is aware of
this this global cache and always use it.

By default, the WP makefile will clone a local copy of the wp-cache in `../wp-cache`
but you can choose another place:

    $ git clone git@git.frama-c.com:frama-c/wp-cache.git <your-cache>
    $ export WP_QUALIF_CACHE=<absolute-path-to-your-cache>

The WP makefile uses `WP_QUALIF_CACHE` environment variable to know where your
local copy of cache has been installed. You shall put it in your global shell
environment. To run individual tests, you may now use:

    $ export FRAMAC_WP_CACHE=update
    $ export FRAMAC_WP_CACHEDIR=$WP_QUALIF_CACHE
    $ ./bin/ptests.opt src/plugins/wp/tests/xxx/yyy.i [-show|-update]

As mentionned above, it is _not_ recommanded to globally set the
`FRAMAC_WP_XXX` variables in your default shell environment, because WP will
use it by default and would merge any new cache entry there, even those
non-related to the `qualif` WP test suite. For this reason,
we recommend to use `WP_QUALIF_CACHE` globally and `FRAMAC_WP_CACHEDIR` locally.
