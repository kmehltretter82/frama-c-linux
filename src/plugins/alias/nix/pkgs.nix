{ frama-c-repo ? builtins.trace "alias: defaulting frama-c-repo to ${toString ../../frama-c}" ../../frama-c }:
let
  ocamlOverlay = oself: osuper: {
    alias = oself.callPackage ./alias.nix {};
  };
  overlay = self: super: {
    ocaml-ng = super.lib.mapAttrs (
      name: value:
        if builtins.hasAttr "overrideScope'" value
        then value.overrideScope' ocamlOverlay
        else value
    ) super.ocaml-ng;
  };
  pkgs = (import (frama-c-repo + "/nix/pkgs.nix")).appendOverlays [ overlay ];
in
pkgs
