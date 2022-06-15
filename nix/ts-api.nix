{ lib
, stdenv
, frama-c
, headache
} :

stdenv.mkDerivation rec {
  pname = "ts-api-check";
  version = frama-c.version;
  slang = frama-c.slang;

  src = frama-c.build_dir + "/dir.tar";
  sourceRoot = ".";

  buildInputs = frama-c.buildInputs ++ [
    frama-c
    headache
  ];

  postPatch = ''
    patchShebangs .
  '' ;
  preConfigure = frama-c.preConfigure;

  # Keep main configuration
  configurePhase = ''
    true
  '';

  buildPhase = ''
    make -C ivette check-api
  '';

  # No installation required
  installPhase = ''
    touch $out
  '';
}
