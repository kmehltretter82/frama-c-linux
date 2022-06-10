let
  sources = import ./sources.nix {};
  ocamlOverlay = oself: osuper: {
    # External Packages
    alt-ergo = oself.callPackage ./alt-ergo.nix {};
    camlzip = oself.callPackage ./camlzip.nix {};
    headache = oself.callPackage ./headache.nix {};
    mlmpfr = oself.callPackage ./mlmpfr.nix {};
    ocp-indent = oself.callPackage ./ocp-indent.nix {};
    odoc = oself.callPackage ./odoc.nix {};
    psmt2-frontend = oself.callPackage ./psmt2-frontend.nix {};
    why3 = oself.callPackage ./why3.nix {};

    # Helpers
    mk_tests = oself.callPackage ./mk_tests.nix {};
    mk_plugin = oself.callPackage ./mk_plugin.nix {};

    # Shell containing checkers (hdrck, ocp-indent)
    frama-c-checkers-shell = oself.callPackage ./frama-c-checkers-shell.nix {
      git = pkgs.git ;
    };

    # Builds
    frama-c = oself.callPackage ./frama-c.nix {};
    frama-c-hdrck = oself.callPackage ./frama-c-hdrck.nix {};
    lint = oself.callPackage ./lint.nix {};

    # Tests
    default-config-tests = oself.callPackage ./default-config-tests.nix {};
    e-acsl-tests = oself.callPackage ./e-acsl-tests.nix {};
    eva-tests = oself.callPackage ./eva-tests.nix {};
    full-tests = oself.callPackage ./full-tests.nix {};
    kernel-tests = oself.callPackage ./kernel-tests.nix {};
    plugins-tests = oself.callPackage ./plugins-tests.nix {};
    wp-tests = oself.callPackage ./wp-tests.nix {};

    # Internal tests
    internal-tests = oself.callPackage ./internal-tests.nix {};

    # Release
    api-doc = oself.callPackage ./api-doc.nix {};
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
