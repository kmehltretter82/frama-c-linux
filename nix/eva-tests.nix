{ mk_tests } :

mk_tests {
  tests-name = "eva-tests";
  tests-command = ''
    dune exec -- frama-c-ptests tests
    dune build -j1 --display short \
      @tests/builtins/ptests \
      @tests/float/ptests \
      @tests/idct/ptests \
      @tests/value/ptests
  '';
}
