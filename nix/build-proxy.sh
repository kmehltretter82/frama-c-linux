#!/usr/bin/env bash
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

# OCAML must be set to the right version of OCAML (format: N_MM or N.MM)

if [[ $# != 1 ]];
then
  cat <<EOF
usage: OCAML=N_MM $0 <nix-target>
  $0 <nix-target> run the nix-build command for this target
EOF
  exit 2
fi

if [ -z ${OCAML+x} ]; then
  echo "OCAML variable must be set to a version of OCaml"
  exit 2
fi

# Normalize version for Nix
OCAML=${OCAML/./_}

OUTOPT=""
if [ ! -z ${OUT+x} ]; then
  OUTOPT="-o $OUT"
fi

if [ -z ${DIR+x} ]; then
  DIR="."
fi

nix-build $OUTOPT $DIR/nix/pkgs.nix -A ocaml-ng.ocamlPackages_$OCAML.$1
