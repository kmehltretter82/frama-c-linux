{ callPackage
, fetchFromGitHub
, lib
, stdenv
, ocaml
, findlib
, ocplib-simplex
, psmt2-frontend
, lablgtk
, zarith
, menhir
, camlzip
, num
, which
, autoreconfHook
}:

stdenv.mkDerivation rec {
  pname = "alt-ergo";
  version = "2.2.0-free";

  src = fetchFromGitHub {
    owner = "OCamlPro";
    repo = pname;
    rev = "refs/tags/"+version;
    sha256 = "11ffm87vsrii8nyhxhbc9gzjmqkspqv7hpjq7ll9xflll7gpnpkj";
  };

  nativeBuildInputs = [
    autoreconfHook
    which
  ];

  buildInputs = [
    ocaml
    findlib
    zarith
    ocplib-simplex
    psmt2-frontend
    lablgtk
    menhir
  ];

  propagatedBuildInputs = [ camlzip num ];

  enableParallelBuilding = true;

  configureFlags = [ "--enable-verbose-make" ];

  meta = {
    description = "High-performance theorem prover and SMT solver";
    homepage    = "https://alt-ergo.ocamlpro.com/";
    license     = lib.licenses.ocamlpro_nc;
    maintainers = [ lib.maintainers.thoughtpolice ];
  };
}
