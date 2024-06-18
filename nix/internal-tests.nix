# Note: plugins are loaded from 'internal-tests.sh'

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
, findlib
# Frama-C build
, apron
, camlzip
, camomile
, clang
, dune_3
, dune-configurator
, dune-site
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
# Frama-C tests
, alt-ergo
, dos2unix
, doxygen
, perl
, pkgs
, python3
, python3Packages
, yq
, swiProlog
, time
, wp-cache
}:

# We do not use buildDunePackage because Frama-C still uses a Makefile to build
# some files and prepare some information before starting dune.
stdenvNoCC.mkDerivation rec {
  pname = "frama-c-internal-tests";
  version =
    lib.strings.replaceStrings ["~"] ["-"]
      (lib.strings.removeSuffix "\n"
        (builtins.readFile ../VERSION));
  slang = lib.strings.removeSuffix "\n" (builtins.readFile ../VERSION_CODENAME);

  src = gitignoreSource ./..;

  nativeBuildInputs = [
    which
    wrapGAppsHook
  ];

  buildInputs = [
    apron
    alt-ergo
    camlzip
    camomile
    clang
    dune_3
    dune-configurator
    dune-site
    findlib
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
    ocp-indent
    ppx_deriving
    ppx_deriving_yaml
    ppx_deriving_yojson
    unionFind
    yojson
    which
    yaml
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
    python3Packages.pyaml
    yq
    swiProlog
    time
  ];

  outputs = [ "out" ];

  preConfigure = ''
    dune build @frama-c-configure
  '';

  # Do not use default parallel building, but allow 2 cores for Frama-C build
  enableParallelBuilding = false;
  buildPhase = ''
    dune build -j2 --display short --error-reporting=twice @install
    make tools/ptests/ptests.exe
    make tools/ptests/wtests.exe
  '';

  wp_cache = wp-cache.src ;

  doCheck = true;
  preCheck = ''
    patchShebangs .
    mkdir home
    HOME=$(pwd)/home
    why3 config detect
    export FRAMAC_WP_CACHE=offline
    export FRAMAC_WP_CACHEDIR=$wp_cache
  '';

  # The export NIX_GCC_DONT_MANGLE_PREFIX_MAP is meant to disable the
  # transformation of the path of Frama-C into uppercase when using the
  # __FILE__ macro.
  checkPhase = ''
    runHook preCheck
    export NIX_GCC_DONT_MANGLE_PREFIX_MAP=
    dune exec -- frama-c-ptests -never-disabled tests src/plugins/*/tests
    dune build -j1 --display short @ptests_config
  '';

  installFlags = [
    "PREFIX=$(out)"
  ];

  meta = {
    description = "An extensible and collaborative platform dedicated to source-code analysis of C software";
    homepage = "http://frama-c.com/";
    license = lib.licenses.lgpl21;
    platforms = lib.platforms.unix;
  };
}
