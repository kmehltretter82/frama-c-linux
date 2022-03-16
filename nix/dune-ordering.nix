{ lib, buildDunePackage, dune_2 }:

buildDunePackage rec {
  pname = "ordering";

  useDune2 = true;

  inherit (dune_2) src version patches;

  minimumOCamlVersion = "4.08";

  dontAddPrefix = true;

  meta = with lib; {
    description = "Private libraries of Dune";
    maintainers = [];
    license = licenses.mit;
  };
}
