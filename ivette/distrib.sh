#!/bin/sh -e
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

# --------------------------------------------------------------------------
# ---  Generate Files for Ivette Distribution
# --------------------------------------------------------------------------

Distribute() {
    repo=$1
    Distrib=$repo/Makefile.distrib
    Headers=$repo/headers/header_spec.txt
    rm -f $Distrib
    rm -f $Headers
    mkdir -p $1/headers
    if [ "$repo" == "." ]
    then
        src=ivette
    else
        src=ivette/$repo
    fi
    echo "Distributing $src"
    echo "HEADER_SPEC += $src/./headers/header_spec.txt" >> $Distrib
    for f in $(git -C $repo ls-files .)
    do
        case $f in
            Makefile.distrib | headers/* | ivette.icns )
            ;;
            *)
                echo "DISTRIB_FILES += $src/$f" >> $Distrib
                case $f in
                    *.sh | *.json | */dome/doc/* | configure.js | sandboxer.js | .* | webpack*.js )
                        echo "$f: .ignore" >> $Headers
                        ;;
                    *Make* | *.js* | *.ts* | *.ml*)
                        echo "$f: CEA_LGPL" >> $Headers
                        ;;
                    *)
                        echo "$f: .ignore" >> $Headers
                        ;;
                esac
        esac
    done
    chmod a-w $Distrib
    chmod a-w $Headers
    if [ "$repo" != "." ]
    then
        echo "include ivette/$Distrib" >> Makefile.plugins
    fi
}

## Distribute Core Ivette Files

Distribute .

## Distribute Ivette Plugins Files

rm -f Makefile.plugins
for rgit in $(find src -type d -name ".git")
do
    Distribute $(dirname $rgit)
done
if [ -f Makefile.plugins ]
then
    chmod a-w Makefile.plugins
fi

## Terminated.
exit 0

# --------------------------------------------------------------------------
