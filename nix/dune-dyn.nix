{ lib, buildDunePackage, dune_2, dune-ordering, pp }:

buildDunePackage rec {
  pname = "dyn";

  useDune2 = true;

  inherit (dune_2) src version patches;
  buildInputs = dune_2.buildInputs ++ [ dune-ordering pp ] ;

  minimumOCamlVersion = "4.08";

  dontAddPrefix = true;

  meta = with lib; {
    description = "Private libraries of Dune";
    maintainers = [];
    license = licenses.mit;
  };
}
