{ lib
, buildDunePackage
, fetchurl
, camlzip
, cmdliner
, dolmen
, dolmen_loop
, dolmen_type
, dune-build-info
, dune-site
, fmt
, menhir
, ocplib-simplex
, ppx_blob
, psmt2-frontend
, seq
, stdlib-shims
, which
, zarith
}:

let
  pname = "alt-ergo";
  version = "2.5.3";

  src = fetchurl {
    url = "https://github.com/OCamlPro/alt-ergo/releases/download/v${version}/alt-ergo-${version}.tbz";
    sha256 = "sha256-tmWLZBLfdmfYlCQq+zcUneeueDAE6AJeZMy8kfNCC04=";
  };
in

let alt-ergo-lib = buildDunePackage rec {
  pname = "alt-ergo-lib";
  inherit version src ;
  nativeBuildInputs = [ which ];
  propagatedBuildInputs = [
    camlzip
    dolmen
    dolmen_loop
    dolmen_type
    dune-build-info
    fmt
    ocplib-simplex
    ppx_blob
    seq
    stdlib-shims
    zarith
  ];
  preBuild = ''
    substituteInPlace src/lib/util/version.ml --replace 'version="dev"' 'version="${version}"'
  '';
}; in

let alt-ergo-parsers = buildDunePackage rec {
  pname = "alt-ergo-parsers";
  inherit version src ;
  nativeBuildInputs = [
    menhir
    which
  ];
  propagatedBuildInputs = [
    alt-ergo-lib
    psmt2-frontend
  ];
}; in

buildDunePackage {
  inherit pname version src ;
  nativeBuildInputs = [
    menhir
    which
  ];
  buildInputs = [
    alt-ergo-parsers
    cmdliner
    dune-site
  ];

  meta = {
    description = "High-performance theorem prover and SMT solver";
    homepage    = "https://alt-ergo.ocamlpro.com/";
    license     = lib.licenses.ocamlpro_nc;
    maintainers = [ lib.maintainers.thoughtpolice ];
  };
}
