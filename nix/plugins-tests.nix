{ lib
, stdenv
, frama-c
, alt-ergo
, perl
, pkgs
, time
, which
}:

# TODO: SPLIT THIS
stdenv.mkDerivation rec {
  pname = "plugins-tests";
  version = frama-c.version;
  slang = frama-c.slang;

  build_dir = frama-c.build_dir;
  src = build_dir + "/dir.tar";
  wp_cache = fetchGit "git@git.frama-c.com:frama-c/wp-cache.git"; # only for WP qualif
  sourceRoot = ".";

  buildInputs = frama-c.buildInputs ++ [
    alt-ergo # only for WP qualif
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
  # Only for WP qualif -> replace with true after split
  configurePhase = ''
    mkdir home
    HOME=$(pwd)/home
    why3 config detect
  '';

  buildPhase = ''
    export FRAMAC_WP_CACHEDIR=$wp_cache
    dune exec -- frama-c-ptests src/plugins/*/tests
    dune build -j1 --display short @src/plugins/ptests
  '';

  # No installation required
  installPhase = ''
    touch $out
  '';
}
