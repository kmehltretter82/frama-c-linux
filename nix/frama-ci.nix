#To copy in other repository
{ password}:

let
    src = builtins.fetchGit {
            "url" = "https://bobot:${password}@git.frama-c.com/frama-c/Frama-CI.git";
            "name" = "Frama-CI";
            "rev" = "ceea8c97fc127db159bfd92919eae404e2e67f18";
            "ref" = "master";
    };
    pkgs = import "${src}/pkgs.nix" {};
 in
 {
  src = src;
  compiled = pkgs.callPackage "${src}/compile.nix" { inherit pkgs; };
 }
