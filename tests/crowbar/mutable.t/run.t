  $ dune build --cache=disabled --root . @install
This test should not timeout, dune error "Rule produced directory" is "normal"
  $ timeout 10.0 dune runtest --cache=disabled --root .
  Running Crowbar tests on mutable
  mutable typeOffset: PASS
  

  $ dune build --cache=disabled --root . _build/default/mutable_const_fail.cmxs

  $ dune build --cache=disabled --root . _build/default/mutable_mutable_fail.cmxs

  $ ./failed_test.sh
