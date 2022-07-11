# TODO:
# - enable lint E-ACSL C files
# - enable check-headers

{ lib
, stdenv
, bc
# , clang_10
, frama-c
# , headache
, ocp-indent
} :

stdenv.mkDerivation rec {
  pname = "lint";
  version = frama-c.version;
  slang = frama-c.slang;

  src = frama-c.src;

  nativeBuildInputs = frama-c.nativeBuildInputs;

  buildInputs = frama-c.buildInputs ++ [
    bc
    # headache
    ocp-indent
    # clang_10
  ];

  preConfigure = frama-c.preConfigure;

  buildPhase = ''
    make lint
    make stats-lint
    # STRICT_HEADERS=yes make check-headers
  '';

  installPhase = ''
    touch $out
  '';
}
