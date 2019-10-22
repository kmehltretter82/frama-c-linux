m4_define([plugin_file],Makefile)

m4_define([FRAMAC_SHARE_ENV],
          [m4_normalize(m4_esyscmd([echo $FRAMAC_SHARE]))])

m4_define([FRAMAC_SHARE],
	  [m4_ifval(FRAMAC_SHARE_ENV,[FRAMAC_SHARE_ENV],
                                     [m4_esyscmd(frama-c -print-path)])])

m4_ifndef([FRAMAC_M4_MACROS],
         [m4_include(FRAMAC_SHARE/configure.ac)]
        )

check_plugin(mdr,PLUGIN_RELATIVE_PATH(plugin_file),[Mardown/SARIF report plug-in],yes)

AC_MSG_CHECKING(for ppx_deriving)
if $OCAMLFIND query ppx_deriving -qo -qe; then
  HAS_PPX_DERIVING=yes;
  AC_MSG_RESULT(yes)
  AC_MSG_CHECKING(for ppx_deriving_yojson)
  if $OCAMLFIND query ppx_deriving_yojson -qo -qe; then
    HAS_PPX_DERIVING_YOJSON=yes;
  else
    HAS_PPX_DERIVING_YOJSON=no;
  fi
  AC_MSG_RESULT($HAS_PPX_DERIVING_YOJSON);
else
  HAS_PPX_DERIVING=no;
  HAS_PPX_DERIVING_YOJSON=no;
  AC_MSG_RESULT(no)
fi

if test "$HAS_PPX_DERIVING_YOJSON" != "yes"; then
   plugin_disable(mdr, [ppx_deriving_yojson not available]);
fi

check_plugin_dependencies

write_plugin_config()
