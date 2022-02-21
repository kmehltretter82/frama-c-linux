let
  sources = import ./sources.nix {};
  ocamlOverlay = oself: osuper: {
    # External Packages
    alt-ergo = oself.callPackage ./alt-ergo.nix {};
    camlzip = oself.callPackage ./camlzip.nix {};
    ocp-indent = oself.callPackage ./ocp-indent.nix {};
    psmt2-frontend = oself.callPackage ./psmt2-frontend.nix {};
    why3 = oself.callPackage ./why3.nix {};
    # Builds
    frama-c = oself.callPackage ./frama-c.nix {};
    lint = oself.callPackage ./lint.nix {};
    # Tests
    main-tests = oself.callPackage ./main-tests.nix {};
    plugins-tests = oself.callPackage ./plugins-tests.nix {};
  };
  overlay = self: super: {
    niv = (import sources.niv {}).niv;
    ocaml-ng = super.lib.mapAttrs (
      name: value:
        if builtins.hasAttr "overrideScope'" value
        then value.overrideScope' ocamlOverlay
        else value
    ) super.ocaml-ng;
    inherit (super.callPackage sources."gitignore.nix" {}) gitignoreSource;
    why3 = throw "don't use pkgs.why3 but ocaml-ng.ocamlPackages_4_XX.why3";
    camlzip = throw "don't use pkgs.camlzip but ocaml-ng.ocamlPackages_4_XX.camlzip";
    framac = throw "don't use pkgs.framac but ocaml-ng.ocamlPackages_4_XX.frama-c";
    frama-c = throw "don't use pkgs.framac but ocaml-ng.ocamlPackages_4_XX.frama-c";
  };
  pkgs = import sources.nixpkgs {
    # alt-ergo
    config.allowUnfree = true;
    overlays = [ overlay ];
  };
in
pkgs
