{
  lib,
  fetchurl,
  fetchFromGitHub,
  buildDunePackage,
  ocaml,
  ocaml-compiler-libs,
  ocaml-migrate-parsetree,
  ppx_derivers,
  stdio,
  stdlib-shims,
  ocaml-migrate-parsetree-2,
}:

buildDunePackage rec {
  pname = "ppxlib";
  version = "0.37.0";

  src = fetchurl {
    url = "https://github.com/ocaml-ppx/ppxlib/releases/download/${version}/ppxlib-${version}.tbz";
    sha256 = "sha256-LiI4N+fOzDvISkMkMsCnL04dW+kWXJwzdy8VbbhdsLM=";
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
