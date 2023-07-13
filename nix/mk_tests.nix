# This template is meant to execute Frama-C tests
#
# Input variables:
#
# - tests-name (mandatory):
#   The name used for the derivation.
#
# - tests-command (mandatory):
#   The tests command to execute, generally something like:
#   ''
#     dune exec -- frama-c-ptests -never-disabled tests src/plugins/e-acsl/tests
#     dune build -j1 --display short @src/plugins/e-acsl/tests/ptests
#   ''
#
# - has-wp-proofs (optional, defaults to 'false')
#   Indicates whether the tests execute WP proofs, if it the case the derivation
#   receives an additional build-input 'alt-ergo'. Furthermore, it configures
#   Why3 before build phase and export the WP global cache. Note however that
#   this cache is used only if the tests use the option '-wp-cache-env'

{ lib
, alt-ergo
, clang
, frama-c
, perl
, stdenvNoCC
, time
, unixtools
, which
, wp-cache
} :

{ tests-name
, tests-command
, has-wp-proofs ? false
, cover ? true
} :

stdenvNoCC.mkDerivation {
  pname = tests-name ;
  version = frama-c.version;
  slang = frama-c.slang;

  src = frama-c.build_dir + "/dir.tar";
  sourceRoot = ".";

  buildInputs = frama-c.buildInputs ++ [
    clang
    frama-c
    perl
    time
    unixtools.getopt
    which
  ] ++
  (if has-wp-proofs then [ alt-ergo ] else []);

  postPatch = ''
    patchShebangs .
  '' ;

  # Keep main configuration
  configurePhase = ''
    true
  '';

  wp_cache =
    if has-wp-proofs
    then wp-cache.src
    else "" ;

  preBuild =
    (if has-wp-proofs
     then ''
         mkdir home
         HOME=$(pwd)/home
         why3 config detect
         export FRAMAC_WP_CACHE=offline
         export FRAMAC_WP_CACHEDIR=$wp_cache
     ''
     else "") +
    (if cover
     then ''
         mkdir coverage
         export DUNE_WORKSPACE="dev/dune-workspace.cover"
         export BISECT_FILE="$(pwd)/coverage/bisect-"
     ''
     else "");

  postBuild =
    if cover
    then ''
      bisect-ppx-report cobertura --coverage-path=coverage coverage.xml
    ''
    else "" ;

  buildPhase = ''
    runHook preBuild
  '' +
  tests-command + ''
    runHook postBuild
  '';

  # No installation required
  installPhase = ''
    mkdir $out
    cp -r coverage.xml $out
  '';
}
