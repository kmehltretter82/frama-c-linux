{ mk_plugin,
  unionFind }:

mk_plugin {
  plugin-name = "alias" ;
  plugin-src = fetchGit { shallow=true ; url=./.. ; } ;
  additional-build-inputs = [
    unionFind
  ] ;
}
