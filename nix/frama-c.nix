# Frama-C build derivation
# Input variables:
# - `cover` (defaults to `true`) that indicates whether Frama-C should be
#   compiled with coverage instrumentation,
# - `release_mode` (defaults to `false`) that indicates whether Frama-C should
#   be compiled in release mode.

{ lib
, stdenvNoCC # for E-ACSL
, fetchurl
, gitignoreSource
, makeWrapper
, nix-gitignore
, wrapGAppsHook
, writeText
# Generic
, findlib
# Frama-C build
, apron
, bisect_ppx
, camlzip
, camomile
, dune_3
, dune-configurator
, dune-site
, fpath
, gcc9
, graphviz
, lablgtk3
, lablgtk3-sourceview3
, ltl2ba
, menhir
, menhirLib
, mlmpfr
, ocaml
, ocamlgraph
, ocamlgraph_gtk
, ocp-indent
, ppx_deriving
, ppx_deriving_yaml
, ppx_deriving_yojson
, unionFind
, yojson
, which
, why3
, yaml
, zarith
, zmq
# Frama-C extra (other targets do not reconfigure)
, dos2unix
, doxygen
, python3
, python3Packages
, cover ? true
, release_mode ? false
}:

# We do not use buildDunePackage because Frama-C still uses a Makefile to build
# some files and prepare some information before starting dune.
stdenvNoCC.mkDerivation rec {
  pname = "frama-c";
  version =
    lib.strings.replaceStrings ["~"] ["-"]
      (lib.strings.removeSuffix "\n"
        (builtins.readFile ../VERSION));
  slang = lib.strings.removeSuffix "\n" (builtins.readFile ../VERSION_CODENAME);

  src =
    if release_mode
    then ./..
    else gitignoreSource ./.. ;

  nativeBuildInputs = [
    which
    wrapGAppsHook
  ];

  buildInputs = [
    apron
    bisect_ppx
    camlzip
    camomile
    dune_3
    dune-configurator
    dune-site
    findlib
    fpath
    gcc9
    graphviz
    lablgtk3
    lablgtk3-sourceview3
    ltl2ba
    menhir
    menhirLib
    mlmpfr
    ocaml
    ocamlgraph
    ocamlgraph_gtk
    ocp-indent
    ppx_deriving
    ppx_deriving_yaml
    ppx_deriving_yojson
    unionFind
    yojson
    which
    why3
    yaml
    zarith
    zmq
    # For other CI targets
    dos2unix
    doxygen
    python3
  ];

  outputs = [ "out" "build_dir" ];

  preConfigure = ''
    dune build @frama-c-configure
  '';

  # Do not use default parallel building, but allow 2 cores for Frama-C build
  enableParallelBuilding = false;
  dune_opt = if release_mode then "--release" else "" ;

  buildPhase = (if cover then ''
      export DUNE_WORKSPACE="dev/dune-workspace.cover"
    '' else "") +
    ''
      dune build -j2 --display short --error-reporting=twice $dune_opt @install

      make tools/ptests/ptests.exe
      make tools/ptests/wtests.exe
    '';

  installFlags = [
    "PREFIX=$(out)"
  ];

  # Simpler for our test target
  # We export the build directory to avoid rebuilding Frama-C without having to
  # manage complex dependencies.
  postInstall = ''
    mkdir -p $build_dir
    tar -cf $build_dir/dir.tar .
  '';

  # Nix moves these directories after they have been installed by Dune and
  # compress manuals ...
  # Note: Required so that tests of external plugins can be executed. Don't know
  # why tests fail without them.
  postFixup = ''
    cp -r $out/share/doc $out/doc
    cp -r $out/share/man $out/man
    gzip -d $out/man/man1/*
  '';

  # Allow loading of external Frama-C plugins
  setupHook = writeText "setupHook.sh" ''
    has_dirs() {
      for f do
        [ -d "$f" ] && return
      done
      false
    }

    addFramaCPath () {
      if test -d "''$1/lib/frama-c/plugins"; then
        export FRAMAC_PLUGIN="''${FRAMAC_PLUGIN-}''${FRAMAC_PLUGIN:+:}''$1/lib/frama-c/plugins"
        export OCAMLPATH="''${OCAMLPATH-}''${OCAMLPATH:+:}''$1/lib/frama-c/plugins"
      fi

      if has_dirs ''$1/lib/frama-c-*; then
        export OCAMLPATH="''${OCAMLPATH-}''${OCAMLPATH:+:}''$1/lib"
        export DUNE_DIR_LOCATIONS="''${DUNE_DIR_LOCATIONS-}''${DUNE_DIR_LOCATIONS:+:}frama-c:lib:''$1/lib/frama-c"
      fi

    }

    addEnvHooks "$targetOffset" addFramaCPath
  '';

  meta = {
    description = "An extensible and collaborative platform dedicated to source-code analysis of C software";
    homepage = "http://frama-c.com/";
    license = lib.licenses.lgpl21;
    platforms = lib.platforms.unix;
  };
}
