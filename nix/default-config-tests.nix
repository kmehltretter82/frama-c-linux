{ mk_tests, frama-c-nocover } :

let mk_tests_distrib = mk_tests.override {
  frama-c = frama-c-nocover ;
}; in
mk_tests_distrib {
  cover = false ;
  tests-name = "src-distrib-tests" ;
  tests-command = ''
    dune exec -- frama-c-ptests -never-disabled tests src/plugins/*/tests
    dune build -j1 --display short @ptests_config
  '' ;
}
