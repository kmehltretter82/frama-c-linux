# paramaterised derivation with dependencies injected (callPackage style)
{ pkgs, stdenv, src ? ../., opam2nix, ocaml_version ? "ocamlPackages_latest.ocaml", plugins ? { } }:

let plugin = plugins.helpers.simple_plugin
  { inherit pkgs stdenv src opam2nix ocaml_version plugins;
    deps = [ pkgs.getopt pkgs.which ];
    name = "e-acsl";
    preBuild = ''
          echo IN_FRAMA_CI=yes > in_frama_ci
    '';
  };

  in
  plugin //
  {
   tests-dev = stdenv.mkDerivation {
         # performs "make tests" in externalized compilation mode
               name = "e-acsl-tests-dev";
               buildInputs = plugin.buildInputs;
               src = plugin.main.build_dir;
               build_dir = plugin.main.build_dir;
               configurePhase = ''
                      true
               '';
               buildPhase = ''
                      tar -xf $build_dir/dir.tar
                      # path substitutions into some files without timestamp modification (for doing tests without re-build)
                      find . \( -name "Makefile*" -or -name ".depend" -o -name "ptests_config" -o -name "config.status" \) -exec bash -c "t=\$(stat -c %y \"\$0\"); sed -i -e \"s&$(cat $build_dir/old_pwd)&$(pwd)&g\" \"\$0\"; touch -d \"\$t\" \"\$0\"" {} \;
                      _callImplicitHook 0 preFramaCTests
                      FRAMAC_PLUGIN="$(pwd):$FRAMAC_PLUGIN"
                      make tests -j 4 PTESTS_OPTS="-error-code -j 4" DEV=yes
               '';
               installPhase = ''
                            true
               '';
         };

}
