#! /usr/bin/env bash
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

# --------------------------------------------------------------------------
# ---  Export Dome API
# --------------------------------------------------------------------------

DOME=$1
COND=''
COND+=' -not -path "*/demo/*"'
COND+=' -not -name "Application.js"'
COND+=' -not -name "Preferences.js"'
COND+=' -not -name "dome.js"'
COND+=' -not -name "index.js"'

FILES=`cd $DOME/src ; find renderer -name "*.js" $COND`

echo "{ let m = require('react'); register('react',m); }"
echo "{ let m = require('dome'); register('dome',m); }"
echo "{ let m = require('dome/system'); register('dome/system',m); }"
for f in $FILES
do
    j=${f/renderer/dome}
    m=${j/.js/}
    echo "{ let m = require('$m'); register('$m',m); }"
done

# --------------------------------------------------------------------------
