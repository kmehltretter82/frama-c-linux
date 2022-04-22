{ lib
, stdenv
, frama-c
, perl
, time
, which
}:

stdenv.mkDerivation rec {
  pname = "default-config-tests";
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
    dune exec -- frama-c-ptests tests src/plugins/*/tests
    dune build -j1 --display short @ptests_config
  '';

  # No installation required
  installPhase = ''
    touch $out
  '';
}
