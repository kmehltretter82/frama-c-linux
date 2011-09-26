##########################################################################
#                                                                        #
#  This file is part of Frama-C.                                         #
#                                                                        #
#  Copyright (C) 2007-2010                                               #
#    CEA (Commissariat à l'Énergie Atomique)                             #
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

########################################
# E-ACSL as a standard Frama-C plug-in #
########################################

m4_define([plugin_file],Makefile.in)

m4_define([FRAMAC_SHARE_ENV],
          [m4_normalize(m4_esyscmd([echo $FRAMAC_SHARE]))])

m4_define([FRAMAC_SHARE],
	  [m4_ifval(FRAMAC_SHARE_ENV,[FRAMAC_SHARE_ENV],
                                     [m4_esyscmd(frama-c -print-path)])])

m4_ifndef([FRAMAC_M4_MACROS], [m4_include(FRAMAC_SHARE/configure.ac)])

check_plugin(e_acsl,PLUGIN_RELATIVE_PATH(plugin_file),
	     [support for E-ACSL plug-in],yes,yes)

###############################
# C specific stuff for E-ACSL #
###############################

MAY_COMPILE_WITH_CC=true
MAY_USE_ASSERT=true
MAY_RUN_TESTS=yes

# C compiler and stdio.h
#########################

AC_CHECK_HEADER(stdio.h,HAVE_STDIO_H=yes,)

# not sure it can actually happens:
# look like the configure stops on error if no C compiler detected
if test -z $CC; then
  MAY_RUN_TESTS=no
  AC_MSG_WARN([no C compiler: non-regression tests unavailable.])
else

if test -z $HAVE_STDIO_H; then
  MAY_COMPILE_WITH_CC=false
  MAY_RUN_TESTS=no
  AC_MSG_WARN([stdio.h missing: cannot use option -e-acsl-include-headers.])
  AC_MSG_WARN([stdio.h missing: non-regression tests unavailable.])
fi

# assert.h
##########

AC_CHECK_HEADER(assert.h,HAVE_ASSERT_H=yes,)

if test -z $HAVE_ASSERT_H; then
  MAY_USE_ASSERT=false
  MAY_RUN_TESTS=no
  AC_MSG_WARN([assert.h missing: cannot use E-ACSL option -e-acsl-use-assert.])
  AC_MSG_WARN([assert.h missing: non-regression tests unavailable.])
fi

# GMP library
#############

AC_CHECK_LIB(gmp,__gmpz_init,HAVE_GMP=yes,) # also set LIBS

if test -z $HAVE_GMP; then
  MAY_COMPILE_WITH_CC=false
  MAY_RUN_TESTS=no
  AC_MSG_WARN([GMP library missing: cannot use E-ACSL option -e-acsl-include-headers.])
  AC_MSG_WARN([GMP library missing: non-regression tests unavailable.])
fi

fi # testing $CC

#######################
# Generating Makefile #
#######################

AC_SUBST(MAY_COMPILE_WITH_CC)
AC_SUBST(MAY_USE_ASSERT)
AC_SUBST(MAY_RUN_TESTS)
AC_SUBST(GMPSRC_DIR)

write_plugin_config(Makefile)
