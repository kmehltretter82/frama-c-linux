{ lib
, stdenv
, clang_11
, frama-c
, frama-c-hdrck
, frama-c-lint
, git
, gnumake
, headache
, ocp-indent
} :
stdenv.mkDerivation rec {
  name = "plugin-checkers-shell";
  buildInputs = [
    clang_11
    frama-c
    frama-c-hdrck
    frama-c-lint
    git
    gnumake
    headache
    ocp-indent
  ];
}
