# Nix
{ lib
, stdenvNoCC # for E-ACSL
, fetchurl
, gitignoreSource
, makeWrapper
, nix-gitignore
, wrapGAppsHook
, writeText
# Generic
, autoconf
, findlib
# Frama-C build
, apron
, camlzip
, dune_3
, dune-site-3
, gcc9
, graphviz
, lablgtk3
, lablgtk3-sourceview3
, ltl2ba
, menhirLib
, mlgmpidl
, ocaml
, ocamlgraph
, ppx_deriving
, ppx_deriving_yojson
, yojson
, which
, why3
, zarith
, zmq
# Frama-C extra (other targets do not reconfigure)
, dos2unix
, doxygen
, python3
}:

# We do not use buildDunePackage because Frama-C still uses a Makefile to build
# some files and prepare some information before starting dune.
stdenvNoCC.mkDerivation rec {
  pname = "frama-c";
  version = lib.strings.removeSuffix "\n" (builtins.readFile ../VERSION);
  slang = lib.strings.removeSuffix "\n" (builtins.readFile ../VERSION_CODENAME);

  src = gitignoreSource ./..;

  nativeBuildInputs = [
    autoconf
    which
    wrapGAppsHook
  ];

  buildInputs = [
    apron
    camlzip
    dune_3
    dune-site-3
    findlib
    gcc9
    graphviz
    lablgtk3
    lablgtk3-sourceview3
    ltl2ba
    menhirLib
    mlgmpidl
    ocaml
    ocamlgraph
    ppx_deriving
    ppx_deriving_yojson
    yojson
    which
    why3
    zarith
    zmq
    # For other CI targets
    dos2unix
    doxygen
    python3
  ];

  outputs = [ "out" "build_dir" ];

  preConfigure = ''
    autoconf
    patchShebangs src/plugins/value/gen-api.sh
    chmod +x src/plugins/value/gen-api.sh
  '';

  # Do not use default parallel building, but allow 2 cores for Frama-C build
  enableParallelBuilding = false;
  buildPhase = ''
    make config.sed
    dune build -j2 --display short @install
    make ptests/ptests.exe
    make ptests/wtests.exe
  '';

  installFlags = [
    "FRAMAC_INSTALLDIR=$(out)"
  ];

  # Simpler for our test target
  postInstall = ''
    mkdir -p $build_dir
    tar -cf $build_dir/dir.tar .
  '';

  # Required so that tests of external plugins can be excuted
  postFixup = ''
    cp -r $out/share/doc $out/doc
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

      if test -d "''$1/share/frama-c/"; then
        export FRAMAC_EXTRA_SHARE="''${FRAMAC_EXTRA_SHARE-}''${FRAMAC_EXTRA_SHARE:+:}''$1/share/frama-c"
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
