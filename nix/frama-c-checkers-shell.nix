{ lib
, stdenv
, black
, clang_10
, frama-c-hdrck
, frama-c-lint
, git
, git-lfs
, gnumake
, headache
, ocp-indent
} :
stdenv.mkDerivation rec {
  name = "frama-c-checkers-shell";
  buildInputs = [
    black
    clang_10
    frama-c-hdrck
    frama-c-lint
    git
    git-lfs
    gnumake
    headache
    ocp-indent
  ];
}
