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
# ---  Compute mode
# --------------------------------------------------------------------------

OPT=""
LOG=""

case $1 in
    "--dev"|"-D")
        OPT="--dev"
        LOG=".dome-pkg-dev"
        shift
        ;;
    "--app"|"-A")
        OPT=""
        LOG=".dome-pkg-app"
        shift
        ;;
    *)
        echo "Require --dev or --app option"
        exit 1
        ;;
esac

# --------------------------------------------------------------------------
# ---  Check for Updates
# --------------------------------------------------------------------------

rm -f $LOG.tmp
echo $* > $LOG.tmp

if [ -f $LOG.lock ]
then
    diff $LOG.tmp $LOG.lock
    if [ $? -eq 0 ]
    then
        rm -f $LOG.tmp
        echo "Packages are up-to-date."
        exit 0
    fi
fi

# --------------------------------------------------------------------------
# ---  Updates Packages
# --------------------------------------------------------------------------

echo "yarn add $OPT $*"
yarn add $OPT $*

if [ $? -eq 0 ]
then
    mv -f $LOG.tmp $LOG.lock
else
    echo "Package installation failed."
    exit 1
fi

# --------------------------------------------------------------------------
