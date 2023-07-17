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
    mkdir coverage
    export BISECT_FILE="$(pwd)/coverage/bisect-"
    make -C ivette check-api
    bisect-ppx-report cobertura --coverage-path=coverage coverage-$pname.xml
    tar cfJ coverage.tar.xz coverage-$pname.xml
  '';

  # No installation required
  installPhase = ''
    mkdir -p $out
    cp -r coverage.tar.xz $out/$pname.tar.xz
  '';
}
