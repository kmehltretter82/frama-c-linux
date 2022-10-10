#!/bin/zsh
##########################################################################
#                                                                        #
#  This file is part of Frama-C.                                         #
#                                                                        #
#  Copyright (C) 2007-2022                                               #
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

echo "Building Ivette"
PWD=`pwd`

# --------------------------------------------------------------------------
echo "[1/3] Configuring"
# --------------------------------------------------------------------------

NODEJS=`node --version`
case $NODEJS in
    v16.*)
        echo " - node $NODEJS found"
        ;;
    *)
        echo "Ivette requires node version 16 to be installed."
        echo "Tip: install nvm and run 'nvm use 16'"
        exit 1 ;;
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

TMPDIR=`mktemp -d -t ivette`
cd $TMPDIR
tar zxf $PREFIX/lib/frama-c/ivette.tgz
cd ivette
make dist
if [ "$?" != "0" ]
then
    echo "Compilation Failed"
    rm -fr $TMPDIR
    exit 2
fi

# --------------------------------------------------------------------------
echo "[3/3] Finalizing Installation"
# --------------------------------------------------------------------------

make PREFIX=$PREFIX install
if [ "$?" != "0" ]
then
    echo "Installation Failed"
    rm -fr $TMPDIR
    exit 3
fi
cd $PWD
rm -fr $TMPDIR
rm -f $PREFIX/lib/frama-c/ivette.tgz

# --------------------------------------------------------------------------
echo "Launching Ivette..."
# --------------------------------------------------------------------------
exec $PREFIX/bin/ivette $*

# --------------------------------------------------------------------------
