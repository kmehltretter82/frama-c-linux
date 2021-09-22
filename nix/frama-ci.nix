#To copy in other repository
{ password}:

let
    src = builtins.fetchGit {
            "url" = "https://bobot:${password}@git.frama-c.com/frama-c/Frama-CI.git";
            "name" = "Frama-CI";
            "rev" = "738ec3236ef5217ee68fabad869f217b37410430";
            "ref" = "fix/interface-files";
    };
    pkgs = import "${src}/pkgs.nix" {};
 in
 {
  src = src;
  compiled = pkgs.callPackage "${src}/compile.nix" { inherit pkgs; };
 }
