{ lib
, stdenv
, autoconf
, clang_10
, frama-c-hdrck
, git
, gnumake
, headache
, ocp-indent
} :
stdenv.mkDerivation rec {
  name = "frama-c-checkers-shell";
  buildInputs = [
    autoconf
    clang_10
    frama-c-hdrck
    git
    gnumake
    headache
    ocp-indent
  ];
}
