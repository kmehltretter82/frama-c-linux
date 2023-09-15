{ lib, fetchurl, buildDunePackage, stdlib-shims }:

buildDunePackage rec {
  pname = "ocamlgraph";
  version = "2.1.0";

  src = fetchurl {
    url = "https://github.com/backtracking/ocamlgraph/releases/download/${version}/ocamlgraph-${version}.tbz";
    sha256 = "sha256-D5YsNvklPfI5OVWvQbB0tqQmsvkqne95WyAFtX0wLWU=";
  };

  minimalOCamlVersion = "4.08";
  useDune2 = true;

  propagatedBuildInputs = [
    stdlib-shims
  ];

  meta = with lib; {
      homepage = "http://ocamlgraph.lri.fr/";
      downloadPage = "https://github.com/backtracking/ocamlgraph";
      description = "Graph library for OCaml";
      license = licenses.gpl2Oss;
      maintainers = with maintainers; [ ];
  };
}
