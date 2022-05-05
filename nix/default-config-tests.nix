{ mk_tests } :

mk_tests {
  tests-name = "default-config-tests";
  tests-command = ''
    dune exec -- frama-c-ptests tests src/plugins/*/tests
    dune build -j1 --display short @ptests_config
  '';
}
