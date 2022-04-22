{ lib
, stdenvNoCC
, frama-c
, perl
, pkgs
, time
, which
}:

stdenvNoCC.mkDerivation rec {
  pname = "e-acsl-tests";
  version = frama-c.version;
  slang = frama-c.slang;

  build_dir = frama-c.build_dir;
  src = build_dir + "/dir.tar";
  sourceRoot = ".";

  buildInputs = frama-c.buildInputs ++ [
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
  configurePhase = ''
    true
  '';

  buildPhase = ''
    dune exec -- frama-c-ptests tests src/plugins/*/tests
    dune build -j1 --display short @src/plugins/e-acsl/tests/ptests
  '';

  # No installation required
  installPhase = ''
    touch $out
  '';
}
