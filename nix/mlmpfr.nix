
{ lib
, fetchFromGitHub
, gmp
, mpfr
, buildDunePackage
}:

buildDunePackage rec {
  pname = "mlmpfr";
  version = "4.1.0-bugfix1";

  minimumOCamlVersion = "4.04";

  src = fetchFromGitHub {
    owner = "thvnx";
    repo = pname;
    rev = pname+"."+version;
    sha256 = "13n6spgz5p6jhpjackvfsn33iinpadgr3v4gm63d5195mi9fgn8d";
  };

  buildInputs = [ gmp mpfr ];

  meta = {
    description = "The package provides bindings for MPFR";
    license = lib.licenses.lgpl3Only;
    maintainers = [ ];
    homepage = "https://github.com/thvnx/mlmpfr";
  };
}
