{ mk_tests, config } :

let eva-tests = "eva-tests" + (if config == "" then "" else "-" + config); in
let ptests = "ptests_config" + (if config == "" then "" else "_" + config) ; in
let tbuiltins = " @tests/builtins/" + ptests ; in
let tfloat = " @tests/float/" + ptests ; in
let tidct = " @tests/idct/" + ptests ; in
let tvalue = " @tests/value/" + ptests ; in

mk_tests {
  tests-name = eva-tests ;
  tests-command = ''
    dune exec -- frama-c-ptests -never-disabled tests
    dune build -j1 --display short'' + tbuiltins + tfloat + tidct + tvalue + "\n" ;
}
