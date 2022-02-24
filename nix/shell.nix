let
  pkgs = import ./pkgs.nix;
  ocamlPackages_for_shell = pkgs.ocaml-ng.ocamlPackages_4_12;
in
pkgs.mkShell {
  nativeBuildInputs = with pkgs; [
    niv
    ocamlPackages_for_shell.merlin
    ocamlPackages_for_shell.ocaml-lsp
    ocamlPackages_for_shell.utop
  ];
  inputsFrom = [ ocamlPackages_for_shell.frama-c ];
}
