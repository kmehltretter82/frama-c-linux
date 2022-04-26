{ lib
, stdenvNoCC
, frama-c
, alt-ergo
, perl
, pkgs
, time
, which
}:

stdenvNoCC.mkDerivation rec {
  pname = "full-tests";
  version = frama-c.version;
  slang = frama-c.slang;

  build_dir = frama-c.build_dir;
  src = build_dir + "/dir.tar";
  wp_cache = fetchGit "git@git.frama-c.com:frama-c/wp-cache.git";
  sourceRoot = ".";

  buildInputs = frama-c.buildInputs ++ [
    alt-ergo
    frama-c
    perl
    pkgs.getopt
    time
    which
  ];

  postPatch = ''
    patchShebangs .
  '' ;

  # Keep main configuration
  # But configure Why3
  configurePhase = ''
    mkdir home
    HOME=$(pwd)/home
    why3 config detect
  '';


  buildPhase = ''
    export FRAMAC_WP_CACHEDIR=$wp_cache
    dune exec -- frama-c-ptests tests src/plugins/*/tests
    dune build @ptests
  '';

  # No installation required
  installPhase = ''
    touch $out
  '';
}
