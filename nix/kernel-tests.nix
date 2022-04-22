{ lib
, stdenv
, frama-c
, perl
, time
, which
}:

stdenv.mkDerivation rec {
  pname = "kernel-tests";
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
      @tests/cil/ptests \
      @tests/compliance/ptests \
      @tests/jcdb/ptests \
      @tests/libc/ptests \
      @tests/misc/ptests \
      @tests/pretty_printing/ptests \
      @tests/saveload/ptests \
      @tests/spec/ptests \
      @tests/syntax/ptests \
      @tests/test/ptests
  '';

  # No installation required
  installPhase = ''
    touch $out
  '';
}
