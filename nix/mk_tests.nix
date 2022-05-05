{ lib
, alt-ergo
, frama-c
, perl
, pkgs
, stdenvNoCC
, time
, which
} :

{ tests-name
, tests-command
, has-wp-proofs ? false
} :

stdenvNoCC.mkDerivation {
  pname = tests-name ;
  version = frama-c.version;
  slang = frama-c.slang;

  src = frama-c.build_dir + "/dir.tar";
  sourceRoot = ".";

  buildInputs = frama-c.buildInputs ++ [
    frama-c
    perl
    pkgs.getopt
    time
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
    then fetchGit "git@git.frama-c.com:frama-c/wp-cache.git"
    else "" ;

  preBuild =
    if has-wp-proofs
    then ''
        mkdir home
        HOME=$(pwd)/home
        why3 config detect
        export FRAMAC_WP_CACHEDIR=$wp_cache
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
    touch $out
  '';
}
