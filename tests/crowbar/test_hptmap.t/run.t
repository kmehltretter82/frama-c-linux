  $ dune build --cache=disabled --root . @install
This test should not timeout
  $ timeout 10.0 dune runtest --cache=disabled --root .
  Running Crowbar tests on hptmap
  hptmap: PASS
  

