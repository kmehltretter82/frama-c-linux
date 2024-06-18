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
# ---  Ivette bootstrapper for OPAM installation
# --------------------------------------------------------------------------

echo "Building Ivette"
USERCWD=`pwd`

# --------------------------------------------------------------------------

function InstallHelp()
{
    echo "Ivette Requirements:"
    echo "  - node v20"
    echo "  - yarn (any version)"
    echo "Recommanded Installation:"
    echo "  - install nvm (https://github.com/nvm-sh/nvm)"
    echo "  - run 'nvm use 20'"
    echo "  - run 'npm install --global yarn'"
    echo "  - run 'ivette'"
}

# --------------------------------------------------------------------------
echo "[1/3] Configuring"
# --------------------------------------------------------------------------

NODEJS=`node --version`
case $NODEJS in
    v20.*)
        echo " - node $NODEJS found"
        ;;
    *)
        echo "Ivette requires node version 20 to be installed."
        echo
        InstallHelp
        exit 1 ;;
esac

YARNJS=`yarn --version`
case $YARNJS in
    1.*)
        echo " - yarn $YARNJS found"
        ;;
    *)
        echo "Ivette requires yarn to be installed."
        echo
        InstallHelp
        exit 1
        ;;
esac

SELF=`dirname $0`
cd $SELF/..
PREFIX=`pwd`

if [ -f $PREFIX/lib/frama-c/ivette.tgz ]
then
    echo " - prefix $PREFIX"
else
    echo "Ivette archive not found ($PREFIX)"
    exit 1
fi

# --------------------------------------------------------------------------
echo "[2/3] Compiling Ivette"
# --------------------------------------------------------------------------

IVETTE_TMP_DIR=`mktemp -d`
cd $IVETTE_TMP_DIR
tar zxf $PREFIX/lib/frama-c/ivette.tgz
cd ivette
make dist
if [ "$?" != "0" ]
then
    echo "Compilation Failed"
    rm -fr $IVETTE_TMP_DIR
    exit 2
fi

# --------------------------------------------------------------------------
echo "[3/3] Finalizing Installation"
# --------------------------------------------------------------------------

make PREFIX=$PREFIX install
if [ "$?" != "0" ]
then
    echo "Installation Failed"
    rm -fr $IVETTE_TMP_DIR
    exit 3
fi
cd $USERCWD
rm -fr $IVETTE_TMP_DIR
rm -f $PREFIX/lib/frama-c/ivette.tgz

# --------------------------------------------------------------------------
echo "Launching Ivette..."
# --------------------------------------------------------------------------
exec $PREFIX/bin/ivette $*

# --------------------------------------------------------------------------
