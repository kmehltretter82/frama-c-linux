{ mk_tests } :

mk_tests {
  tests-name = "wp-tests";
  tests-command = ''
    dune exec -- frama-c-ptests -never-disabled src/plugins/wp/tests
    dune build -j1 --display short @src/plugins/wp/tests/ptests
  '';
  has-wp-proofs = true ;
}
