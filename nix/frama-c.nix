# Nix
{ lib
, stdenv
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
, graphviz
, ltl2ba
, ocamlPackages
, which
, why3
# Frama-C extra (other targets do not reconfigure)
, dos2unix
, doxygen
, python3
}:

# We do not use buildDunePackage because Frama-C still uses a Makefile to build
# some files and prepare some information before starting dune.
stdenv.mkDerivation rec {
  pname = "frama-c";
  version = lib.strings.removeSuffix "\n" (builtins.readFile ../VERSION);
  slang = lib.strings.removeSuffix "\n" (builtins.readFile ../VERSION_CODENAME);

  src = gitignoreSource ./..;

  nativeBuildInputs = [
    autoconf
    which
    wrapGAppsHook
  ];

  buildInputs = with ocamlPackages; [
    apron
    camlzip
    dune_3
    dune-site
    findlib
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
  '';

  buildPhase = ''
    make config.sed
    dune build -j2 --display short @install
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

  # Required so that Frama-C libs are found after install
  setupHook = writeText "setupHook.sh" ''
    export OCAMLPATH="''${OCAMLPATH-}''${OCAMLPATH:+:}''$1/lib"
  '';

  meta = {
    description = "An extensible and collaborative platform dedicated to source-code analysis of C software";
    homepage = "http://frama-c.com/";
    license = lib.licenses.lgpl21;
    platforms = lib.platforms.unix;
  };
}
