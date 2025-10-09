  $ dune build --cache=disabled --root . @install
This test should not timeout, dune error "Rule produced directory" is "normal"
  $ timeout 10.0 dune runtest --cache=disabled --root .
  Running Crowbar tests on mutable
  mutable typeOffset: PASS
  
  File "dune", lines 12-15, characters 0-82:
  12 | (rule
  13 |  (alias runtest)
  14 |  (target (dir failed_cases))
  15 |  (action (run ./mutable.exe)))
  Error: Rule produced directory "failed_cases" that contains no files nor
  non-empty subdirectories
  [1]

  $ dune build --cache=disabled --root . _build/default/mutable_const_fail.cmxs

  $ dune build --cache=disabled --root . _build/default/mutable_mutable_fail.cmxs

  $ ./failed_test.sh
