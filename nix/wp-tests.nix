{ mk_tests } :

mk_tests {
  tests-name = "wp-tests";
  tests-command = ''
    dune exec -- frama-c-ptests -never-disabled plugins/wp/tests
    dune build -j1 @plugins/wp/tests/ptests
    dune build -j1 @runtest-wp
  '';
  has-wp-proofs = true ;
}
