{ lib
, stdenv
, frama-c
, headache
, texlive
} :

stdenv.mkDerivation rec {
  pname = "manuals";
  version = frama-c.version;
  slang = frama-c.slang;


  build_dir = frama-c.build_dir + "/dir.tar";
  acsl = fetchGit {
    url = "https://github.com/acsl-language/acsl.git";
    name = "acsl";
  };
  srcs = [
    build_dir
    acsl
  ] ;

  sourceRoot = ".";

  buildInputs = frama-c.buildInputs ++ [
    frama-c
    headache
    texlive.combined.scheme-full
  ];

  postUnpack = ''
    mv acsl doc
  '' ;

  postPatch = ''
    patchShebangs .
  '' ;

  # Keep main configuration
  configurePhase = ''
    true
  '';

  buildPhase = ''
    NO_SUFFIX="yes" ./doc/build-manuals.sh
  '';

  installPhase = ''
    mkdir -p $out
    cp ./doc/manuals/*.pdf $out
  '';
}
