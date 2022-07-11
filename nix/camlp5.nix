
{ lib
, stdenv
, fetchFromGitHub
, findlib
, camlp-streams
, ocaml
, ocaml-compiler-libs
, perl
}:

if lib.versionOlder ocaml.version "4.02"
|| lib.versionOlder "4.15" ocaml.version
then throw "camlp5 is not available for OCaml ${ocaml.version}"
else

stdenv.mkDerivation rec {

  pname = "camlp5";
  version = "8.00.03";

  src = fetchFromGitHub {
    owner = "camlp5";
    repo = "camlp5";
    rev = "rel${version}";
    sha256 = "1fnvmaw9cland09pjx5h6w3f6fz9s23l4nbl4m9fcaa2i4dpraz6";
  };

  buildInputs = [ findlib camlp-streams ocaml perl ];

  prefixKey = "-prefix ";

  preConfigure = ''
    configureFlagsArray=(--strict --libdir $out/lib/ocaml/${ocaml.version}/site-lib)
    patchShebangs ./config/find_stuffversion.pl
    patchShebangs ./etc/META.pl
  '';

  buildFlags = [ "world.opt" ];

  dontStrip = true;

  meta = with lib; {
    description = "Preprocessor-pretty-printer for OCaml";
    longDescription = ''
      Camlp5 is a preprocessor and pretty-printer for OCaml programs.
      It also provides parsing and printing tools.
    '';
    homepage = "https://camlp5.github.io/";
    license = licenses.bsd3;
    platforms = ocaml.meta.platforms or [];
    maintainers = with maintainers; [
      maggesi vbgl
    ];
  };
}
