{ mk_tests } :

mk_tests {
  tests-name = "plugins-tests";
  tests-command = ''
    dune exec -- frama-c-ptests -never-disabled tests src/plugins/*/tests
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
      @src/plugins/alias/tests/ptests \
      @src/plugins/dive/tests/ptests \
      @src/plugins/instantiate/tests/ptests \
      @src/plugins/loop_analysis/tests/ptests \
      @src/plugins/markdown-report/tests/ptests \
      @src/plugins/nonterm/tests/ptests \
      @src/plugins/report/tests/ptests \
      @src/plugins/server/tests/ptests \
      @src/plugins/variadic/tests/ptests
  '';
  has-wp-proofs = true ;
}
