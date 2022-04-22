{ lib
, stdenvNoCC # for E-ACSL
, frama-c
, perl
, time
, which
}:

stdenvNoCC.mkDerivation rec {
  pname = "eva-tests";
  version = frama-c.version;
  slang = frama-c.slang;

  build_dir = frama-c.build_dir;
  src = build_dir + "/dir.tar";
  sourceRoot = ".";

  buildInputs = frama-c.buildInputs ++ [
    frama-c
    perl
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
    dune exec -- frama-c-ptests tests
    dune build -j1 --display short \
      @tests/builtins/ptests \
      @tests/float/ptests \
      @tests/idct/ptests \
      @tests/value/ptests \
      @tests/value/traces/ptests
  '';

  # No installation required
  installPhase = ''
    touch $out
  '';
}
