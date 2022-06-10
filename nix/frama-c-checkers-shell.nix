{ lib
, stdenv
, frama-c-hdrck
, git
, gnumake
, headache
, ocp-indent
} :
stdenv.mkDerivation rec {
  name = "frama-c-checkers-shell";
  buildInputs = [
    frama-c-hdrck
    git
    gnumake
    headache
    ocp-indent
  ];
}
