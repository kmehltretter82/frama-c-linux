{ lib, buildDunePackage, fetchurl, ppxlib, alcotest, ppx_deriving, yaml }:

buildDunePackage rec {
  pname = "ppx_deriving_yaml";
  version = "0.2.1";

  minimalOCamlVersion = "4.08";
  duneVersion = "3";

  src = fetchurl {
    url = "https://github.com/patricoferris/ppx_deriving_yaml/releases/download/v${version}/ppx_deriving_yaml-${version}.tbz";
    sha256 = "sha256-3vmay8UY7d3j96VOQ+D3oYEotzVls91F51ebXWQ/9SQ=";
  };

  propagatedBuildInputs = [ ppxlib ppx_deriving yaml ];

  meta = {
    description = "A YAML codec generator for OCaml";
    homepage = "https://github.com/patricoferris/ppx_deriving_yaml";
    license = lib.licenses.isc;
    maintainers = [ ];
  };
}
