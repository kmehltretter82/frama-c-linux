#!/bin/sh -eu
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

DIR=$(dirname $0)

export FRAMA_CI_NIX=$DIR/frama-ci.nix
export FRAMA_CI=$(nix-instantiate --eval -E "((import <nixos-20.03> {}).callPackage $FRAMA_CI_NIX  { password = \"$TOKEN_FOR_API\";}).src.outPath")

FRAMA_CI=${FRAMA_CI#\"}
FRAMA_CI=${FRAMA_CI%\"}

export NIX_PATH="nixpkgs=$(eval echo $(nix-instantiate --eval -E "with import $FRAMA_CI/pkgs-ref.nix; url"))"
$FRAMA_CI/compile.sh $@
