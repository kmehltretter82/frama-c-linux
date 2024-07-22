#!/usr/bin/bash -eu
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

# Script used to quickly generate a Frama-C Docker image based on the
# current state of the repository

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

cd "$SCRIPT_DIR/../"
USE_STASH=yes dev/make-distrib.sh
mv "frama-c-current.tar.gz" "$SCRIPT_DIR/docker/frama-c-current.tar.gz"
cd "$SCRIPT_DIR/docker"
FRAMAC_ARCHIVE="frama-c-current.tar.gz" make custom-fast.debian

if command -v podman 2>&1; then
    DOCKER=podman
else
    DOCKER=docker
fi

"$DOCKER" tag frama-c-custom-fast.debian frama-c-current

echo "Created Docker image: frama-c-current"
