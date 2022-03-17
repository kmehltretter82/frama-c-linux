{ lib, buildDunePackage, dune_2, csexp, pp, dune-dyn, dune-stdune, dune-ordering }:

buildDunePackage rec {
  pname = "dune-private-libs";

  useDune2 = true;

  inherit (dune_2) src version patches;
  buildInputs = dune_2.buildInputs ++ [ dune-stdune dune-dyn dune-ordering csexp pp ] ;

  minimumOCamlVersion = "4.08";

  dontAddPrefix = true;

  meta = with lib; {
    description = "Private libraries of Dune";
    maintainers = [ maintainers.marsam ];
    license = licenses.mit;
  };
}
