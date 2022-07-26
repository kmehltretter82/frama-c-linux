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

# This file is the main makefile of Frama-C.

MAKECONFIG_DIR=share

include share/Makefile.common

##############################################################################
# DUNE OPTIONS
################################

DUNE_BUILD_OPTS?=

RELEASE?=no
ifeq ($(RELEASE),yes)
DUNE_BUILD_OPTS+=--release
endif

# DUNE_DISPLAY: chose Dune build verbosity (see '--display' dune option)
# Default: progress (same as dune default)
# Recommend for tests: short
DUNE_DISPLAY?=progress
DUNE_BUILD_OPTS+=--display $(DUNE_DISPLAY)

##############################################################################
# PTESTS SRC
################################

FRAMAC_PTESTS_SRC:=tools/ptests

##############################################################################
# HDRCK SRC
################################

FRAMAC_HDRCK_SRC:=tools/hdrck

##############################################################################
# Frama-C
################################

.PHONY: all

all:
ifneq ($(DISABLED_PLUGINS),)
	dune clean
	rm -rf _build .merlin
	./dev/disable-plugins.sh ${DISABLED_PLUGINS}
endif
	dune build $(DUNE_BUILD_OPTS) @install

clean:: purge-tests # to be done before a "dune" command
	dune clean
	dune clean --root $(FRAMAC_PTESTS_SRC)
	dune clean --root $(FRAMAC_HDRCK_SRC)
	rm -rf _build .merlin

##############################################################################
# HELP
################################

help::
	@echo "Build configuration variables"
	@echo "  - RELEASE: compile in release mode if set to 'yes'"
	@echo "  - DUNE_DISPLAY: parameter transmitted to dune --display option"
	@echo "  - DISABLED_PLUGINS: disable these plugins before (re)building"
	@echo "    (none for enabling all plugins)"

##############################################################################
# INSTALL/UNINSTALL
################################

include share/Makefile.installation

###############################################################################
# HEADER MANAGEMENT
################################

# HDRCK is internal
FRAMAC_HDRCK:=headers/hdrck.exe

# Part that can be shared for external plugins
include share/Makefile.headers

###############################################################################
# Testing
################################

# PTESTS is internal
FRAMAC_PTESTS:=$(FRAMAC_PTESTS_SRC)/ptests.exe

# WTESTS is internal
FRAMAC_WTESTS:=$(FRAMAC_PTESTS_SRC)/wtests.exe

# Frama-C also have ptest directories in plugins, so we do not use default
PTEST_ALL_DIRS:=tests $(wildcard src/plugins/*/tests)

# Test aliasing definition allowing ./configure --disable-<plugin>
PTEST_ALIASES:=@tests/ptests @src/plugins/ptests

# WP tests need WP cache
PTEST_USE_WP_CACHE:=yes

# Part that can be shared for external plugins
include share/Makefile.testing

###############################################################################

# Code prettyfication and lint
include share/Makefile.linting

###############################################################################
# Local Variables:
# compile-command: "make"
# End:
