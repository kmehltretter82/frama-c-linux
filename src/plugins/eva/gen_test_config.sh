#!/bin/bash
##########################################################################
#                                                                        #
#  This file is part of Frama-C.                                         #
#                                                                        #
#  Copyright (C) 2007-2024                                               #
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

# This scripts creates the ptests config files for the alternative testing
# configurations of Eva. You must create the tests/test_config and
# tests/builtins/test_config yourselves. The other files are created
# accordingly. The syntax for the root test_config files is as follows
# (2 lines):
#
# MACRO: EVA_CONFIG  <options inherited in all tests>
# OPT: @EVA_CONFIG@  <default options, inherited in tests that use STDOPT>

# All tested domains
declare -a domains=(
    "apron"
    "bitwise"
    "equalities"
    "gauges"
    "symblocs"
)
# Option(s) corresponding to each domain
declare -a opts=(
    "-eva-apron-oct -value-msg-key experimental-ok"
    "-eva-bitwise-domain"
    "-eva-equality-domain"
    "-eva-gauges-domain"
    "-eva-symbolic-locations-domain"
)

arraylength=${#domains[@]}

cd tests
CUR=`pwd`

#TODO: générer le test_config de builtins à partir de celui racine ?

for A in  . builtins
do
    cd $CUR/$A

    for (( i=0; i<${arraylength}; i++ ));
    do
        echo "`head -1 test_config` ${opts[$i]}" > test_config_${domains[$i]}
        tail -1 test_config >> test_config_${domains[$i]}
    done
done
