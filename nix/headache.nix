{ lib
, camomile
, fetchFromGitHub
, buildDunePackage
, cmdliner
}:

buildDunePackage rec {
  version = "v1.05";
  pname = "headache";

  src = fetchFromGitHub {
    owner = "Frama-C";
    repo = pname;
    rev = version;
    sha256 = "036lrcxh23j2rrj91wlgq9piyyv1vh82wjy63z1l1ggkkhfs7d8r";
  };

  useDune2 = true;

  buildInputs = [
    cmdliner
    camomile
  ];

  meta = with lib; {
    homepage = https://github.com/Frama-C/headache/;
    description = "Automatic generation of files headers";
    license = licenses.gpl2;
    maintainers = [ ];
  };
}
