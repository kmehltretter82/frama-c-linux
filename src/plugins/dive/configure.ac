##########################################################################
#                                                                        #
#  This file is part of the Frama-C plug-in `IIG'.                       #
#                                                                        #
#  Copyright (C) 2018                                                    #
#    CEA (Commissariat à l'énergie atomique et aux énergies              #
#         alternatives)                                                  #
#                                                                        #
#  you can redistribute it and/or modify it under the terms of the GNU   #
#  Lesser General Public License as published by the Free Software       #
#  Foundation, version 2.1.                                              #
#                                                                        #
#  It is distributed in the hope that it will be useful,                 #
#  but WITHOUT ANY WARRANTY; without even the implied warranty of        #
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         #
#  GNU Lesser General Public License for more details.                   #
#                                                                        #
#  See the GNU Lesser General Public License version 2.1                 #
#  for more details (enclosed in the file licenses/LGPLv2.1).            #
#                                                                        #
##########################################################################

m4_define([plugin_file],Makefile.in)

m4_define([FRAMAC_SHARE_ENV],
          [m4_normalize(m4_esyscmd([echo $FRAMAC_SHARE]))])

m4_define([FRAMAC_SHARE],
	  [m4_ifval(FRAMAC_SHARE_ENV,[FRAMAC_SHARE_ENV],
                                     [m4_esyscmd(frama-c -print-path)])])

m4_ifndef([FRAMAC_M4_MACROS], [m4_include(FRAMAC_SHARE/configure.ac)])

check_plugin(iig,PLUGIN_RELATIVE_PATH(plugin_file),
             [support for IIG plug-in],yes)

# Check Frama-C version
#######################

if test -n "$FRAMAC_VERSION"; then

AC_MSG_CHECKING(for Frama-C version)

DEV_VERSION_NUMBER=`echo $FRAMAC_VERSION | sed -e 's/.*-\(.*\)/\1/' `
VERSION_NUMBER=`echo $DEV_VERSION_NUMBER | sed -e 's/\(.*\)+dev/\1/' `
DEV=`echo $DEV_VERSION_NUMBER | sed -e 's/.*\(+dev\)/\1/' `

REQUIRED_VERSION=20140301
VERSION_NAME=Neon

if test $VERSION_NUMBER -lt $REQUIRED_VERSION; then
  AC_MSG_ERROR(Frama-C version must be $VERSION_NAME-$REQUIRED_VERSION.)
else if test $VERSION_NUMBER -gt $REQUIRED_VERSION; then
  AC_MSG_WARN(Frama-C version higher than $VERSION_NAME-$REQUIRED_VERSION not tested: use it at your own risk.)
else
  AC_MSG_RESULT($VERSION_NAME-$REQUIRED_VERSION$DEV: good!)
fi
fi

# at the time being, must use the Frama-C development version
if test "$DEV" != "+dev"; then
  AC_MSG_ERROR(Frama-C version must be the current SVN version.);
fi

fi

# Plug-in dependencies
######################

plugin_require(iig,value,studia)
#plugin_use(iig,usable_plugin_but_not_mandatory)

check_plugin_dependencies

#######################
# Generating Makefile #
#######################

write_plugin_config(Makefile)
