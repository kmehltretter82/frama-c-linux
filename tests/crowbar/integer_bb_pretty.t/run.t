  $ dune build --cache=disabled --root . @install
If this test times out (code 124), try to increase the value below
  $ timeout 10.0 dune runtest --cache=disabled --root .
  Running Crowbar tests on integer_bb_pretty
  pp_bin_hex: PASS
  
