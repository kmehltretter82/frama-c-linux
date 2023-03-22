##########################################################################
#                                                                        #
#  This file is part of the Frama-C plug-in 'Alias' (alias).             #
#                                                                        #
#  Copyright (C) 2022-2023                                               #
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
#  for more details (enclosed in the file LICENSE)                       #
#                                                                        #
##########################################################################

.PHONY: all build-profiling build clean

FRAMAC_SHARE:=$(shell frama-c -print-share-path)

sinclude ${FRAMAC_SHARE}/Makefile.common

##########################################################################
# Build

all:: build frama-c-alias.opam

frama-c-alias.opam: frama-c-alias.opam.template dune-project
	rm -f $@
	dune build $@

build::
	dune build @install

build-profiling::
	dune build --instrument-with landmarks @install

clean:: purge-tests
	dune clean
	rm -rf _build .merlin

##########################################################################
# Tests

include ${FRAMAC_SHARE}/Makefile.testing

##########################################################################
# Install

include ${FRAMAC_SHARE}/Makefile.installation

##########################################################################
# Headers

HDRCK_EXTRA:=-headache-config-file ${FRAMAC_SHARE}/headache_config.txt
include ${FRAMAC_SHARE}/Makefile.headers

SHORT_NAME:=alias
LONG_NAME:=Alias
PLUGIN_NAME:=Alias
FROM_YEAR:=2022

include headers/Makefile.generate-headers

##########################################################################
# Linting

include ${FRAMAC_SHARE}/Makefile.linting

##########################################################################
