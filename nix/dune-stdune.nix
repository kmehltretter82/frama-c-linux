{ lib, buildDunePackage, dune_2, dune-ordering, dune-dyn, csexp, pp }:

buildDunePackage rec {
  pname = "stdune";

  useDune2 = true;

  inherit (dune_2) src version patches;
  buildInputs = dune_2.buildInputs ++ [ dune-ordering dune-dyn csexp pp ] ;

  minimumOCamlVersion = "4.08";

  dontAddPrefix = true;

  meta = with lib; {
    description = "Private libraries of Dune";
    maintainers = [];
    license = licenses.mit;
  };
}
