# paramaterised derivation with dependencies injected (callPackage style)
{ pkgs, stdenv, src ? ../., opam2nix, ocaml_version ? "ocaml-ng.ocamlPackages_4_05.ocaml", plugins ? { } }:

let mk_buildInputs = { opamPackages ? [], nixPackages ? [] } :
    [ pkgs.gnugrep pkgs.gnused  pkgs.autoconf pkgs.gnumake pkgs.gcc pkgs.ncurses pkgs.time pkgs.python3 pkgs.perl pkgs.file pkgs.which] ++ nixPackages ++ opam2nix.build {
           specs = opam2nix.toSpecs ([ "ocamlfind" "zarith" "ocamlgraph" "yojson"
                { name = "coq"; constraint = "=8.11.1";  }
                { name = "why3" ; constraint = "=1.3.1"; }
                { name = "why3-coq" ; constraint = "=1.3.1"; }
                { name = "menhir"; constraint = "=20190924"; }
                { name = "dune"; constraint = "=1.11.4"; }
                { name = "camlzip"; constraint = "=1.07"; }  #so that why3 is always compiled with it
                ] ++ opamPackages
              );
           ocamlAttr = ocaml_version;
        };

in

rec {
  inherit src mk_buildInputs;
  buildInputs = mk_buildInputs {};
  installed = main.out;
  main = stdenv.mkDerivation {
        name = "frama-c";
        inherit src buildInputs;
        outputs = [ "out" "build_dir" ];
        postPatch = ''
               patchShebangs .
        '';
        configurePhase = ''
               unset CC
               autoconf
               ./configure --prefix=$out
        '';
        buildPhase = ''
                make -j 4
        '';
        installPhase = ''
               make install
               mkdir -p $build_dir
               tar -cf $build_dir/dir.tar .
               pwd > $build_dir/old_pwd
        '';
        setupHook = pkgs.writeText "setupHook.sh" ''
          addFramaCPath () {
            if test -d "$1/lib/frama-c/plugins"; then
              export FRAMAC_PLUGIN="''${FRAMAC_PLUGIN:-}''${FRAMAC_PLUGIN:+:}$1/lib/frama-c/plugins"
              export OCAMLPATH="''${OCAMLPATH:-}''${OCAMLPATH:+:}$1/lib/frama-c/plugins"
            fi

            if test -d "$1/lib/frama-c"; then
              export OCAMLPATH="''${OCAMLPATH:-}''${OCAMLPATH:+:}$1/lib/frama-c"
            fi

            if test -d "$1/share/frama-c/"; then
              export FRAMAC_EXTRA_SHARE="''${FRAMAC_EXTRA_SHARE:-}''${FRAMAC_EXTRA_SHARE:+:}$1/share/frama-c"
            fi

          }

          addEnvHooks "$targetOffset" addFramaCPath
        '';
  };

  lint = stdenv.mkDerivation {
        name = "frama-c-lint";
        inherit src;
        buildInputs = (mk_buildInputs { opamPackages = [ { name = "ocp-indent"; constraint = "=1.7.0"; } ];} )
                      ++ [ pkgs.bc plugins.headache.installed ];
        outputs = [ "out" ];
        postPatch = ''
               patchShebangs .
        '';
        configurePhase = ''
               unset CC
               autoconf
               ./configure --prefix=$out
        '';
        buildPhase = ''
               make lint
               make stats-lint
               make check-headers
        '';
        installPhase = ''
               true
        '';
  };

  tests = stdenv.mkDerivation {
        name = "frama-c-test";
        inherit buildInputs;
        build_dir = main.build_dir;
        src = main.build_dir + "/dir.tar";
        sourceRoot = ".";
        postUnpack = ''
               find . \( -name "Makefile*" -or -name ".depend" -o -name "ptests_config" -o -name "config.status" \) -exec bash -c "t=\$(stat -c %y \"\$0\"); sed -i -e \"s&$(cat $build_dir/old_pwd)&$(pwd)&g\" \"\$0\"; touch -d \"\$t\" \"\$0\"" {} \;
        '';
        configurePhase = ''
           true
        '';
        buildPhase = ''
               make clean_share_link
               make create_share_link
               make tests -j4 PTESTS_OPTS="-error-code -j 4"
        '';
        installPhase = ''
               true
        '';
  };

  build-distrib-tarball = stdenv.mkDerivation {
        name = "frama-c-build-distrib-tarball";
        inherit src;
        buildInputs = buildInputs ++ [ plugins.headache.installed ];
        outputs = [ "out" ];
        postPatch = ''
               patchShebangs .
        '';
        configurePhase = ''
               unset CC
               autoconf
               ./configure --prefix=$out
        '';
        buildPhase = ''
                make DISTRIB="frama-c-archive" src-distrib
                tar -zcf frama-c-tests-archive.tar.gz tests src/plugins/*/tests
        '';
        installPhase = ''
               tar -C $out --strip-components=1 -xzf frama-c-archive.tar.gz
               tar -C $out -xzf frama-c-tests-archive.tar.gz
        '';
  };

  build-from-distrib-tarball = stdenv.mkDerivation {
        name = "frama-c-build-from-distrib-tarball";
        inherit buildInputs;
        src = build-distrib-tarball.out ;
        outputs = [ "out" ];
        configurePhase = ''
               unset CC
               autoconf
               ./configure --prefix=$out
        '';
        buildPhase = ''
                make -j 4
        '';
        installPhase = ''
               true
        '';
  };

  wp-qualif = stdenv.mkDerivation {
        name = "frama-c-wp-qualif";
        buildInputs = mk_buildInputs { opamPackages = [
                    { name = "alt-ergo"; constraint = "=2.2.0"; }
               ]; };
        build_dir = main.build_dir;
        src = main.build_dir + "/dir.tar";
        sourceRoot = ".";
        postUnpack = ''
               find . \( -name "Makefile*" -or -name ".depend" -o -name "ptests_config" -o -name "config.status" \) -exec bash -c "t=\$(stat -c %y \"\$0\"); sed -i -e \"s&$(cat $build_dir/old_pwd)&$(pwd)&g\" \"\$0\"; touch -d \"\$t\" \"\$0\"" {} \;
        '';
        configurePhase = ''
           true
        '';
        buildPhase = ''
               make clean_share_link
               make create_share_link
               mkdir home
               HOME=$(pwd)/home
               why3 config --full-config
               bin/ptests.opt -error-code -config qualif src/plugins/wp/tests
        '';
        installPhase = ''
               true
        '';
  };

  e-acsl-tests-dev = stdenv.mkDerivation {
        name = "frama-c-e-acsl-tests-dev";
        buildInputs = mk_buildInputs { nixPackages = [ pkgs.gmp pkgs.getopt ]; };
        build_dir = main.build_dir;
        src = main.build_dir + "/dir.tar";
        sourceRoot = ".";
        postUnpack = ''
               find . \( -name "Makefile*" -or -name ".depend" -o -name "ptests_config" -o -name "config.status" \) -exec bash -c "t=\$(stat -c %y \"\$0\"); sed -i -e \"s&$(cat $build_dir/old_pwd)&$(pwd)&g\" \"\$0\"; touch -d \"\$t\" \"\$0\"" {} \;
        '';
        configurePhase = ''
           true
        '';
        buildPhase = ''
               make clean_share_link
               make create_share_link
               make E_ACSL_TESTS PTESTS_OPTS="-error-code" DEV=yes
        '';
        installPhase = ''
               true
        '';
  };

  internal = stdenv.mkDerivation {
        name = "frama-c-internal";
        inherit src;
        buildInputs = (mk_buildInputs { opamPackages = [ "xml-light" ]; } ) ++
                    [ pkgs.getopt
                      pkgs.libxslt pkgs.libxml2 pkgs.autoPatchelfHook stdenv.cc.cc.lib
        ];
        counter_examples_src = plugins.counter-examples.src;
        genassigns_src = plugins.genassigns.src;
        pathcrawler_src = plugins.pathcrawler.src;
        mthread_src = plugins.mthread.src;
        caveat_importer_src = plugins.caveat-importer.src;
        acsl_importer_src = plugins.acsl-importer.src;
        volatile_src = plugins.volatile.src;
        security_src = plugins.security.src;
        context_from_precondition_src = plugins.context-from-precondition.src;
        postPatch = ''
               patchShebangs .
        '';
        postUnpack = ''
           cp -r --preserve=mode "$counter_examples_src" "$sourceRoot/src/plugins/counter-examples"
           chmod -R u+w -- "$sourceRoot/src/plugins/counter-examples"
           cp -r --preserve=mode "$genassigns_src" "$sourceRoot/src/plugins/genassigns"
           chmod -R u+w -- "$sourceRoot/src/plugins/genassigns"
           cp -r --preserve=mode "$pathcrawler_src" "$sourceRoot/src/plugins/pathcrawler"
           chmod -R u+w -- "$sourceRoot/src/plugins/pathcrawler"
           cp -r --preserve=mode "$mthread_src" "$sourceRoot/src/plugins/mthread"
           chmod -R u+w -- "$sourceRoot/src/plugins/mthread"
           cp -r --preserve=mode "$caveat_importer_src" "$sourceRoot/src/plugins/caveat-importer"
           chmod -R u+w -- "$sourceRoot/src/plugins/caveat-importer"
           cp -r --preserve=mode "$volatile_src" "$sourceRoot/src/plugins/volatile"
           chmod -R u+w -- "$sourceRoot/src/plugins/volatile"
           cp -r --preserve=mode "$acsl_importer_src" "$sourceRoot/src/plugins/acsl-importer"
           chmod -R u+w -- "$sourceRoot/src/plugins/acsl-importer"
           echo IN_FRAMA_CI=yes > "$sourceRoot/in_frama_ci"
           cp -r --preserve=mode "$context_from_precondition_src" "$sourceRoot/src/plugins/context-from-precondition"
           chmod -R u+w -- "$sourceRoot/src/plugins/context-from-precondition"
           cp -r --preserve=mode "$security_src" "$sourceRoot/src/plugins/security"
           chmod -R u+w -- "$sourceRoot/src/plugins/security"
           '';

        configurePhase = ''
               unset CC
               autoconf
               ./configure --prefix=$out
        '';
        buildPhase = ''
                make unpack-eclipse
                sed -i src/plugins/pathcrawler/extern/eclipseCLP/RUNME -e "s/chmod 2755/chmod 755/g"
                rm src/plugins/pathcrawler/extern/eclipseCLP/lib/x86_64_linux/dbi_mysql.so
                rm src/plugins/pathcrawler/extern/eclipseCLP/lib/x86_64_linux/ic.so
                autoPatchelf src/plugins/pathcrawler
                make -j 4
                ln -sr src/plugins/pathcrawler/share share/pc
                make tests -j4 PTESTS_OPTS="-error-code -j 4"
        '';
        installPhase = ''
               make install
        '';
  };

}
