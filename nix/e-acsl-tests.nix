{ mk_tests } :

mk_tests {
  tests-name = "e-acsl-tests" ;
  tests-command = ''
    dune exec -- frama-c-ptests -never-disabled tests plugins/e-acsl/tests
    dune build -j1 @plugins/e-acsl/runtest @plugins/e-acsl/tests/ptests
  '';
}
