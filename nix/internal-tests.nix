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
# Frama-Clang
, cmake
, camlp5
, camlp-streams
, gnused
, llvmPackages
# Frama-C build
, apron
, camlzip
, camomile
, clang
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
, ocp-indent
, ppx_deriving
, ppx_deriving_yaml
, ppx_deriving_yojson
, unionFind
, yojson
, why3
, yaml
, zarith
, zmq
# Frama-C tests
, alt-ergo
, check-jsonschema
, dos2unix
, jq
, perl
, python3
, python3Packages
, swiProlog
, time
, unixtools
, which
, wp-cache
, yq
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

  # Prevent CMake from doing stuff without being asked
  dontUseCmakeConfigure=true;

  nativeBuildInputs = [
    which
    wrapGAppsHook
  ];

  buildInputs = [
    apron
    camlp5
    camlp-streams
    camlzip
    camomile
    clang
    cmake
    dune_3
    dune-configurator
    dune-site
    findlib
    fpath
    gcc9
    gnused
    graphviz
    lablgtk3
    lablgtk3-sourceview3
    llvmPackages.llvm.dev
    llvmPackages.clang-unwrapped.dev
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
    why3
    yaml
    zarith
    zmq
    # Tests
    alt-ergo
    check-jsonschema
    dos2unix
    jq
    perl
    python3
    python3Packages.jsonschema
    python3Packages.pyaml
    swiProlog
    time
    unixtools.getopt
    which
    yq
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
