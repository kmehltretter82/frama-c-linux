
{ lib
, fetchFromGitHub
, gmp
, mpfr
, buildDunePackage
, dune-configurator
}:

buildDunePackage rec {
  pname = "mlmpfr";
  version = "4.2.1";

  minimumOCamlVersion = "4.04";

  src = fetchFromGitHub {
    owner = "thvnx";
    repo = pname;
    rev = pname+"."+version;
    sha256 = "1pr1kl50r4s03z3biwhwvbg6pplwsgbdh2mg60r316hij1fdvkvg";
  };

  patches = [ ./mlmpfr.patch ];
  buildInputs = [ dune-configurator ];
  propagatedBuildInputs = [ gmp mpfr ];

  meta = {
    description = "The package provides bindings for MPFR";
    license = lib.licenses.lgpl3Only;
    maintainers = [ ];
    homepage = "https://github.com/thvnx/mlmpfr";
  };
}
