{ lib
, stdenv
, frama-c
, alt-ergo
, perl
, time
, which
}:

stdenv.mkDerivation rec {
  pname = "wp-tests";
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
    time
    which
  ];

  postPatch = ''
    patchShebangs .
  '' ;

  configurePhase = ''
    mkdir home
    HOME=$(pwd)/home
    why3 config detect
  '';

  buildPhase = ''
    export FRAMAC_WP_CACHEDIR=$wp_cache
    dune exec -- frama-c-ptests src/plugins/wp/tests
    dune build -j1 --display short @src/plugins/wp/tests/ptests
  '';

  # No installation required
  installPhase = ''
    touch $out
  '';
}
