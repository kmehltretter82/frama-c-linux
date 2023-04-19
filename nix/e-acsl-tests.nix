{ mk_tests, config } :

let e-acsl-tests = "e-acsl-tests" + (if config == "" then "" else "-" + config); in
let ptests = "ptests_config" + (if config == "" then "" else "_" + config) ; in
let tests = " @src/plugins/e-acsl/tests/" + ptests ; in

mk_tests {
  tests-name = e-acsl-tests ;
  tests-command = ''
    dune exec -- frama-c-ptests -never-disabled tests src/plugins/e-acsl/tests
    dune build -j1 --display short'' + tests + "\n" ;
}
