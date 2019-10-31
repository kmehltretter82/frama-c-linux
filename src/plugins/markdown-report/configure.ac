m4_define([plugin_file],Makefile.in)

m4_define([FRAMAC_SHARE_ENV],
          [m4_normalize(m4_esyscmd([echo $FRAMAC_SHARE]))])

m4_define([FRAMAC_SHARE],
	  [m4_ifval(FRAMAC_SHARE_ENV,[FRAMAC_SHARE_ENV],
                                     [m4_esyscmd(frama-c -print-path)])])

m4_ifndef([FRAMAC_M4_MACROS],
         [m4_include(FRAMAC_SHARE/configure.ac)]
        )

check_plugin(mdr,PLUGIN_RELATIVE_PATH(plugin_file),[Mardown/SARIF report plug-in],yes)

plugin_require_pkg(mdr,ppx_deriving)
plugin_require_pkg(mdr,ppx_deriving_yojson)

configure_pkg(ppx_deriving,[package ppx_deriving not found])
configure_pkg(ppx_deriving_yojson,[package ppx_deriving_yojson not found])

check_plugin_dependencies

write_plugin_config(Makefile)
