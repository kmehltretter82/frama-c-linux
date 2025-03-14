{ mk_tests } :

mk_tests {
  tests-name = "mthread-tests";
  tests-command = ''
    dune exec -- frama-c-ptests -never-disabled src/plugins/eva/tests
    dune build -j1 @src/plugins/eva/tests/mthread/ptests
    '';
}
