This test should not timeout, dune error "Rule produced directory" is "normal"
  $ timeout 10.0 dune runtest
  Running Crowbar tests on complete_type
  complete type: PASS
  
  File "dune", lines 6-9, characters 0-88:
  6 | (rule
  7 |  (alias runtest)
  8 |  (target (dir failed_cases))
  9 |  (action (run ./complete_type.exe)))
  Error: Rule produced directory "failed_cases" that contains no files nor
  non-empty subdirectories
  [1]

  $ find _build/default/failed_cases -name '*.i' -not -empty -exec cat '{}' ';' -exec frama-c -no-autoload-plugins '{}' ';'

