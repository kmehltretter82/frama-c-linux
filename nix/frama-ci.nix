#To copy in other repository
{ password}:

let
    src = builtins.fetchGit {
            "url" = "https://bobot:${password}@git.frama-c.com/frama-c/Frama-CI.git";
            "name" = "Frama-CI";
            "rev" = "8419895dcec583fb0f0a88a2279d65076827fa30";
            "ref" = "fix/interface-files";
    };
    pkgs = import "${src}/pkgs.nix" {};
 in
 {
  src = src;
  compiled = pkgs.callPackage "${src}/compile.nix" { inherit pkgs; };
 }
