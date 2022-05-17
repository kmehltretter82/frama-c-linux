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
, dune-site
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
, ppx_import
, yojson
, which
, why3
, zarith
, zmq
# Frama-C tests
, alt-ergo
, dos2unix
, doxygen
, perl
, pkgs
, python3
, swiProlog
, time
}:

# We do not use buildDunePackage because Frama-C still uses a Makefile to build
# some files and prepare some information before starting dune.
stdenvNoCC.mkDerivation rec {
  pname = "frama-c-internal-tests";
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
    alt-ergo
    camlzip
    dune_3
    dune-site
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
    ppx_import
    yojson
    which
    why3
    zarith
    zmq
    # Tests
    alt-ergo
    dos2unix
    doxygen
    perl
    pkgs.getopt
    python3
    swiProlog
    time
  ];

  outputs = [ "out" ];

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

  wp_cache = fetchGit "git@git.frama-c.com:frama-c/wp-cache.git";

  doCheck = true;
  preCheck = ''
    patchShebangs .
    mkdir home
    HOME=$(pwd)/home
    why3 config detect
    export FRAMAC_WP_CACHEDIR=$wp_cache
  '';

  checkPhase = ''
    runHook preCheck
    dune exec -- frama-c-ptests tests src/plugins/*/tests
    dune build -j1 --display short @ptests_config
  '';

  installFlags = [
    "FRAMAC_INSTALLDIR=$(out)"
  ];

  meta = {
    description = "An extensible and collaborative platform dedicated to source-code analysis of C software";
    homepage = "http://frama-c.com/";
    license = lib.licenses.lgpl21;
    platforms = lib.platforms.unix;
  };
}
