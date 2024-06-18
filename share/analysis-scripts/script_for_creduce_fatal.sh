#!/bin/bash -e
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

# Script to reduce a Frama-C crashing test case.

# This script requires no modification.
# Names between '@'s will be replaced by creduce.sh.

set +e
"@FRAMAC@" "@BASE@" @FCFLAGS@
retcode=$?
# see cmdline.ml for the different exit codes returned by Frama-C
if [ $retcode -eq 125 -o $retcode -eq 4 ]; then
    exit 0
else
    exit 1
fi
set -e
