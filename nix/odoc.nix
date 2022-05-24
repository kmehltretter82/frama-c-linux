{ lib
, astring
, buildDunePackage
, cmdliner
, cppo
, fetchFromGitHub
, fmt
, fpath
, ocaml
, odoc-parser
, result
, tyxml
}:

buildDunePackage rec {
  pname = "odoc";
  version = "2.1.0";

  minimumOCamlVersion = "4.02";

  src = fetchFromGitHub {
    owner = "ocaml";
    repo = pname;
    rev = version;
    sha256 = "1ycb468pc6vsvqj176j99bmbkrr9saxvyn9qhpazi01abbcq5d90";
  };

  buildInputs = [ astring cmdliner cppo fmt fpath odoc-parser result tyxml ];

  meta = {
    description = "A documentation generator for OCaml";
    license = lib.licenses.isc;
    maintainers = [ lib.maintainers.vbgl ];
    homepage = "https://github.com/ocaml/odoc";
  };
}
