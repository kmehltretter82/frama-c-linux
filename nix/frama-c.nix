# Nix
{ lib
, stdenv
, fetchurl
, gitignoreSource
, makeWrapper
, nix-gitignore
, wrapGAppsHook
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
    dune_2
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

  postInstall = ''
    mkdir -p $build_dir
    tar -cf $build_dir/dir.tar .
    pwd > $build_dir/old_pwd
  '';

  meta = {
    description = "An extensible and collaborative platform dedicated to source-code analysis of C software";
    homepage = "http://frama-c.com/";
    license = lib.licenses.lgpl21;
    platforms = lib.platforms.unix;
  };
}
