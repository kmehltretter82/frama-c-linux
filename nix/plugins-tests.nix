{ mk_tests } :

let plugins = [
  "acsl-importer"
  "aorai"
  "alias"
  "callgraph"
  "constant_propagation"
  "dive"
  "instantiate"
  "impact"
  "loop_analysis"
  "markdown-report"
  "metrics"
  "nonterm"
  "occurrence"
  "pdg"
  "report"
  "region"
  "rte"
  "scope"
  "server"
  "slicing"
  "sparecode"
  "volatile"
]; in
let ptests_aliases =
  builtins.toString
    (builtins.map (plugin: "@src/plugins/" + plugin + "/tests/ptests") plugins);
in
let runtest_aliases =
  builtins.toString
    (builtins.map (plugin: "@src/plugins/" + plugin + "/runtest") plugins);
in

mk_tests {
  tests-name = "plugins-tests";
  tests-command = ''
    dune exec -- frama-c-ptests -never-disabled src/plugins/*/tests
    dune build -j1 ${ptests_aliases}
    dune build -j1 ${runtest_aliases}
  '';
  has-wp-proofs = true ;
}
