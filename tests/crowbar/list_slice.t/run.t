  $ dune build --cache=disabled --root . @install

If this test times out (code 124), try to increase the value below
  $ timeout 200.0 dune runtest --cache=disabled --root .
  Running Crowbar tests on list_slice
  List.slice: PASS
  

