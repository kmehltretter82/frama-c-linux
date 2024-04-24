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

# This file is the main makefile of Frama-C.

MAKECONFIG_DIR=share
FRAMAC_DEVELOPER?=

include $(MAKECONFIG_DIR)/Makefile.common

##############################################################################
# TOOLS CONFIG
################################

IN_FRAMAC:=yes

FRAMAC_PTESTS_SRC:=tools/ptests
FRAMAC_HDRCK_SRC:=tools/hdrck
FRAMAC_LINTCK_SRC:=tools/lint

##############################################################################
# Frama-C
################################

.PHONY: all

DUNE_WS?=

ifneq (${DUNE_WS},)
  WORKSPACE_OPT:=--workspace dev/dune-workspace.${DUNE_WS}
else
  WORKSPACE_OPT:=
endif

DISABLED_PLUGINS?=

all::
ifeq (${FRAMAC_DEVELOPER},yes)
	dune build --no-print-directory --root ${FRAMAC_LINTCK_SRC}
	dune build --no-print-directory --root ${FRAMAC_HDRCK_SRC}
endif
ifneq ($(DISABLED_PLUGINS),)
	dune clean
	rm -rf _build .merlin
	./dev/disable-plugins.sh ${DISABLED_PLUGINS}
endif
	dune build ${WORKSPACE_OPT} ${DUNE_BUILD_OPTS} @install

clean:: purge-tests # to be done before a "dune" command
ifeq (${FRAMAC_DEVELOPER},yes)
	dune clean --no-print-directory --root ${FRAMAC_LINTCK_SRC}
	dune clean --no-print-directory --root ${FRAMAC_HDRCK_SRC}
endif
	dune clean
	rm -rf _build .merlin

##############################################################################
# IVETTE
################################

.PHONY: ivette ivette-api ivette-dev

ivette: ivette-api
	@$(MAKE) -C ivette

ivette-dev: ivette-api
	@$(MAKE) -C ivette dev

ivette-api: all
	@$(MAKE) -C ivette api

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

install:: all

INSTALL_TARGET=Frama-C
include share/Makefile.installation
include ivette/Makefile.installation

ifeq (${FRAMAC_DEVELOPER},yes)

install::
	@echo "Installing frama-c-hdrck and frama-c-lint"
	dune install --root ${FRAMAC_HDRCK_SRC} --prefix ${PREFIX} ${MANDIR_OPT} 2> /dev/null
	dune install --root ${FRAMAC_LINTCK_SRC} --prefix ${PREFIX} ${MANDIR_OPT} 2> /dev/null

uninstall::
	@echo "Uninstalling frama-c-hdrck and frama-c-lint"
	dune uninstall --root ${FRAMAC_HDRCK_SRC} --prefix ${PREFIX} ${MANDIR_OPT} 2> /dev/null
	dune uninstall --root ${FRAMAC_LINTCK_SRC} --prefix ${PREFIX} ${MANDIR_OPT} 2> /dev/null

endif

###############################################################################
# HEADER MANAGEMENT
################################

# Part that can be shared for external plugins
include share/Makefile.headers

###############################################################################
# Testing
################################

# PTESTS is internal
FRAMAC_PTESTS:=$(FRAMAC_PTESTS_SRC)/ptests.exe

# WTESTS is internal
FRAMAC_WTESTS:=$(FRAMAC_PTESTS_SRC)/wtests.exe

# Frama-C also has ptest directories in plugins, so we do not use default
PTEST_ALL_DIRS:=tests $(wildcard src/plugins/*/tests) \
  src/kernel_internals/parsing/tests

# Test aliasing definition allowing ./configure --disable-<plugin>
PTEST_ALIASES:=@tests/ptests @src/plugins/ptests \
  @src/kernel_internals/parsing/tests/ptests

# WP tests need WP cache
PTEST_USE_WP_CACHE:=yes

# Part that can be shared for external plugins
include share/Makefile.testing

###############################################################################
# Linters
################################

# Code prettyfication and lint
include share/Makefile.linting

###############################################################################
# Frama-C Documentation
################################

include share/Makefile.documentation

###############################################################################
# Local Variables:
# compile-command: "make"
# End:
