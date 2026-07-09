{ mk_tests } :

mk_tests {
  tests-name = "kernel-tests";
  tests-command = ''
    dune exec -- frama-c-ptests -never-disabled tests
    dune build -j1 @tests/ptests
    dune runtest -j1 tests
    dune build -j1 @runtest-frama_c_kernel @runtest-parsing
    make -C share/machdeps check-schema
  '';
}
