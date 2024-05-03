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
#
# - cover (optional, defaults to 'true')
#   Indicates whether the tests should generate coverage files. BEWARE! If you
#   disable this, make sure that you use a Frama-C version built without
#   coverage instrumentation, else Frama-C might be build several times during
#   the pipeline. See for example default-config-tests.nix

{ lib
, alt-ergo
, cvc4
, clang
, frama-c
, perl
, python3Packages
, stdenvNoCC
, time
, unixtools
, yq
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
    python3Packages.jsonschema
    time
    unixtools.getopt
    yq
    which
  ] ++
  (if has-wp-proofs then [ alt-ergo cvc4 ] else []);

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
         mkdir -p _bisect
         export DUNE_WORKSPACE="dev/dune-workspace.cover"
         export BISECT_FILE="$(pwd)/_bisect/bisect-"
     ''
     else "");

  postBuild =
    if cover
    then ''
      bisect-ppx-report cobertura --coverage-path=_bisect coverage-$pname.xml
      tar cfJ coverage.tar.xz coverage-$pname.xml
    ''
    else "" ;

  # The export NIX_GCC_DONT_MANGLE_PREFIX_MAP is meant to disable the
  # transformation of the path of Frama-C into uppercase when using the
  # __FILE__ macro.
  buildPhase = ''
    runHook preBuild
    export NIX_GCC_DONT_MANGLE_PREFIX_MAP=
  '' +
  tests-command + ''
    runHook postBuild
  '';

  # No installation required
  installPhase =
    if cover
    then ''
      mkdir -p $out
      cp -r coverage.tar.xz $out/$pname.tar.xz
    ''
    else ''
      touch $out
    '';
}
