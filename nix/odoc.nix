{ lib, fetchurl, buildDunePackage, ocaml
, astring, cmdliner, cppo, fpath, result, tyxml
, odoc-parser, fmt, crunch
}:

buildDunePackage rec {
  pname = "odoc";
  version = "2.4.1";

  src = fetchurl {
    url = "https://github.com/ocaml/odoc/releases/download/${version}/odoc-${version}.tbz";
    sha256 = "sha256-uBSguQILUD62fxfR2alp0FK2PYzcfN+l+3k7E3VYzts=";
  };

  nativeBuildInputs = [ cppo crunch ];
  buildInputs = [ astring cmdliner fpath result tyxml odoc-parser fmt ];

  doCheck = false;

  meta = {
    description = "A documentation generator for OCaml";
    license = lib.licenses.isc;
    maintainers = [ lib.maintainers.vbgl ];
    homepage = "https://github.com/ocaml/odoc";
    changelog = "https://github.com/ocaml/odoc/blob/${version}/CHANGES.md";
  };
}
