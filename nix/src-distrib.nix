{ lib
, stdenv
, frama-c
# , headache
, git
} :

stdenv.mkDerivation rec {
  pname = "src-distrib";
  version = frama-c.version;
  slang = frama-c.slang;

  src = ./.. ;

  nativeBuildInputs = frama-c.nativeBuildInputs;

  buildInputs = frama-c.buildInputs ++ [
    # headache
    git
  ];

  configurePhase = ''
    autoconf
  '';

  preBuild = ''
    patchShebangs ./devel_tools/make-distrib.sh
  '';

  buildPhase = ''
    runHook preBuild
    ./devel_tools/make-distrib.sh
  '';

  installPhase = ''
    mkdir -p $out
    cp frama-c.tar.gz $out
  '';
}
