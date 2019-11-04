# paramaterised derivation with dependencies injected (callPackage style)
{ pkgs, stdenv, src ? ../., opam2nix, ocaml_version ? "ocamlPackages_latest.ocaml", plugins ? { } }:

plugins.helpers.simple_plugin
  { inherit pkgs stdenv src opam2nix ocaml_version plugins;
    deps = [ pkgs.getopt pkgs.which ];
    name = "e-acsl";
    preBuild = ''
          echo IN_FRAMA_CI=yes > in_frama_ci
    '';
  }
