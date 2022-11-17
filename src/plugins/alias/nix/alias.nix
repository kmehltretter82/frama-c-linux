{ mk_plugin }:

mk_plugin {
  plugin-name = "alias" ;
  plugin-src = fetchGit { shallow=true ; url=./.. ; } ;
}
