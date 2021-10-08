#To copy in other repository
{ password}:

let
    src = builtins.fetchGit {
            "url" = "https://bobot:${password}@git.frama-c.com/frama-c/Frama-CI.git";
            "name" = "Frama-CI";
            "rev" = "22ccb4e8951b6ac6eb62b0b0c6a53f9a98c94951";
            "ref" = "master";
    };
    pkgs = import "${src}/pkgs.nix" {};
 in
 {
  src = src;
  compiled = pkgs.callPackage "${src}/compile.nix" { inherit pkgs; };
 }
