  $ dune build --cache=disabled --root . @install
This test should timeout (code 124)
  $ timeout 100.0 dune runtest --cache=disabled
  [124]

This error is normal since we exited because of a timeout, if we ever get an
error before the timeout, it should be displayed here.
  $ find _build/default/failed_cases -name '*.i' -not -empty -exec cat '{}' ';' -exec frama-c -no-autoload-plugins '{}' ';'
  find: '_build/default/failed_cases': No such file or directory
  [1]

