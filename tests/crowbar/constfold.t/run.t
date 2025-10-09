  $ dune build --cache=disabled --root . @install
This test should timeout
  $ timeout 10.0 dune runtest --cache=disabled --root .
  [124]
