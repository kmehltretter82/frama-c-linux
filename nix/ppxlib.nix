{ lib, fetchurl, buildDunePackage, ocaml,
  stdlib-shims, ocaml-compiler-libs, ppx_derivers, stdio
}:

buildDunePackage rec {
  pname = "ppxlib";
  version = "0.32.0";

  duneVersion = "3";

  src = fetchurl {
    url = "https://github.com/ocaml-ppx/ppxlib/releases/download/${version}/ppxlib-${version}.tbz";
    sha256 = "sha256-UHzHPM+JXyLutSV6IkODjBijigkQX8/1Xu75FIVVQis=";
  };

  propagatedBuildInputs = [
    ocaml-compiler-libs
    ppx_derivers
    stdio
    stdlib-shims
  ];

  meta = {
    description = "Comprehensive ppx tool set";
    license = lib.licenses.mit;
    maintainers = [ lib.maintainers.vbgl ];
    homepage = "https://github.com/ocaml-ppx/ppxlib";
  };
}
