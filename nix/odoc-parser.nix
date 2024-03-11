{ lib, fetchurl, buildDunePackage, ocaml, astring, result, camlp-streams }:

buildDunePackage rec {
  pname = "odoc-parser";
  version = "2.4.1";

  minimalOCamlVersion = "4.02";

  src = fetchurl {
    url = "https://github.com/ocaml/odoc/releases/download/${version}/odoc-${version}.tbz";
    sha256 = "sha256-uBSguQILUD62fxfR2alp0FK2PYzcfN+l+3k7E3VYzts=";
  };

  propagatedBuildInputs = [ astring result camlp-streams ];

  meta = {
    description = "Parser for Ocaml documentation comments";
    license = lib.licenses.isc;
    maintainers = [ lib.maintainers.marsam ];
    homepage = "https://github.com/ocaml-doc/odoc-parser";
    changelog = "https://github.com/ocaml-doc/odoc-parser/raw/${version}/CHANGES.md";
  };
}
