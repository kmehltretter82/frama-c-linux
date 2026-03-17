  $ dune build --cache=disabled --root . @install
If this test times out, try to increase the value below
  $ timeout 100.0 dune runtest --cache=disabled --root .
  Running Crowbar tests on constfold
  constfold: PASS
  
