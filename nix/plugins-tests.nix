{ lib
, stdenvNoCC
, frama-c
, alt-ergo
, perl
, time
, which
}:

stdenvNoCC.mkDerivation rec {
  pname = "plugins-tests";
  version = frama-c.version;
  slang = frama-c.slang;

  build_dir = frama-c.build_dir;
  src = build_dir + "/dir.tar";
  wp_cache = fetchGit "git@git.frama-c.com:frama-c/wp-cache.git"; # for Aorai
  sourceRoot = ".";

  buildInputs = frama-c.buildInputs ++ [
    alt-ergo # only for Aorai
    frama-c
    perl
    time
    which
  ];

  postPatch = ''
    patchShebangs .
  '' ;

  # Keep main configuration
  # But for Aorai, configure Why3
  configurePhase = ''
    mkdir home
    HOME=$(pwd)/home
    why3 config detect
  '';

  buildPhase = ''
    export FRAMAC_WP_CACHEDIR=$wp_cache # for Aorai
    dune exec -- frama-c-ptests tests src/plugins/*/tests
    dune build -j1 --display short \
      @tests/callgraph/ptests \
      @tests/constant_propagation/ptests \
      @tests/impact/ptests \
      @tests/metrics/ptests \
      @tests/occurrence/ptests \
      @tests/pdg/ptests \
      @tests/slicing/ptests \
      @tests/rte/ptests \
      @tests/rte_manual/ptests \
      @tests/scope/ptests \
      @tests/sparecode/ptests \
      @src/plugins/aorai/tests/ptests \
      @src/plugins/dive/tests/ptests \
      @src/plugins/instantiate/tests/ptests \
      @src/plugins/loop_analysis/tests/ptests \
      @src/plugins/markdown-report/tests/ptests \
      @src/plugins/nonterm/tests/ptests \
      @src/plugins/report/tests/ptests \
      @src/plugins/server/tests/ptests \
      @src/plugins/variadic/tests/ptests
  '';

  # No installation required
  installPhase = ''
    touch $out
  '';
}
