This test should not timeout
  $ timeout 10.0 dune runtest
  [124]

  $ find _build/default/failed_cases -name '*.i' -not -empty -exec cat '{}' ';' -exec frama-c -no-autoload-plugins '{}' ';'
  find: '_build/default/failed_cases': No such file or directory
  [1]

