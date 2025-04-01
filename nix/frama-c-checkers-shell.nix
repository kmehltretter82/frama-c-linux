{ lib
, stdenv
, black
, clang_19
, combinetura
, frama-c-hdrck
, frama-c-lint
, git
, git-lfs
, gnumake
, headache
, jq
, ocp-indent
} :
stdenv.mkDerivation rec {
  name = "frama-c-checkers-shell";
  buildInputs = [
    black
    clang_19
    combinetura
    frama-c-hdrck
    frama-c-lint
    git
    git-lfs
    gnumake
    headache
    jq
    ocp-indent
  ];
}
