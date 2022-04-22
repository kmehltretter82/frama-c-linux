let
  sources = import ./sources.nix {};
  ocamlOverlay = oself: osuper: {
    # External Packages
    alt-ergo = oself.callPackage ./alt-ergo.nix {};
    camlzip = oself.callPackage ./camlzip.nix {};
    headache = oself.callPackage ./headache.nix {};
    ocp-indent = oself.callPackage ./ocp-indent.nix {};
    psmt2-frontend = oself.callPackage ./psmt2-frontend.nix {};
    why3 = oself.callPackage ./why3.nix {};
    # Nix + Dune 3
    dune-build-3 =
      osuper.buildDunePackage.override {
        dune_2 = oself.dune_3;
      };
    dune-ordering-3 =
      oself.callPackage ./dune-ordering.nix {
        dune_2 = oself.dune_3;
        buildDunePackage = oself.dune-build-3;
      };
    dune-dyn-3 =
      oself.callPackage ./dune-dyn.nix {
        dune_2 = oself.dune_3;
        buildDunePackage = oself.dune-build-3;
        dune-ordering = oself.dune-ordering-3;
      };
    dune-stdune-3 =
      oself.callPackage ./dune-stdune.nix {
        dune_2 = oself.dune_3;
        buildDunePackage = oself.dune-build-3;
        dune-ordering = oself.dune-ordering-3;
        dune-dyn = oself.dune-dyn-3;
      };
    dune-private-libs-3 =
      oself.callPackage ./dune-private-libs.nix {
        dune_2 = oself.dune_3;
        buildDunePackage = oself.dune-build-3;
        dune-ordering = oself.dune-ordering-3;
        dune-stdune = oself.dune-stdune-3;
        dune-dyn = oself.dune-dyn-3;
      };
    dune-site-3 =
      osuper.dune-site.override {
        dune_2 = oself.dune_3;
        buildDunePackage = oself.dune-build-3;
        dune-private-libs = oself.dune-private-libs-3;
      };
    # Builds
    frama-c = oself.callPackage ./frama-c.nix {};
    lint = oself.callPackage ./lint.nix {};
    # Tests
    e-acsl-tests = oself.callPackage ./e-acsl-tests.nix {};
    eva-tests = oself.callPackage ./eva-tests.nix {};
    kernel-tests = oself.callPackage ./kernel-tests.nix {};
    plugins-tests = oself.callPackage ./plugins-tests.nix {};
    wp-tests = oself.callPackage ./wp-tests.nix {};
    # Release
    manuals = oself.callPackage ./manuals.nix {};
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
