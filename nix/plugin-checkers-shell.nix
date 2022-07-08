{ lib
, stdenv
, frama-c
, git
, gnumake
, headache
, ocp-indent
} :
stdenv.mkDerivation rec {
  name = "plugin-checkers-shell";
  buildInputs = [
    frama-c
    git
    gnumake
    headache
    ocp-indent
  ];
}
