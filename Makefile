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

# PTESTS SRC
FRAMAC_PTESTS_SRC:=tools/ptests

# HDRCK SRC
FRAMAC_HDRCK_SRC:=tools/hdrck

###################
# Frama-C Version #
###################

VERSION:=$(shell $(CAT) VERSION)
VERSION_CODENAME:=$(shell $(CAT) VERSION_CODENAME)

.PHONY: all

all: config.sed
	dune build $(DUNE_BUILD_OPTS) @install

MAJOR_VERSION=$(shell $(SED) -E 's/^([0-9]+)\..*/\1/' VERSION)
MINOR_VERSION=$(shell $(SED) -E 's/^[0-9]+\.([0-9]+).*/\1/' VERSION)
VERSION_CODENAME=$(shell $(CAT) VERSION_CODENAME)

# File used by dune to build src/kernel_internals/runtime/fc_config.ml
config.sed: VERSION share/Makefile.config share/Makefile.common Makefile configure.ac
	@echo "# generated file" > $@
	@echo "s|@VERSION@|$(VERSION)|" >> $@
	@echo "s|@VERSION_CODENAME@|$(VERSION_CODENAME)|" >> $@
	@echo "s|@MAJOR_VERSION@|$(MAJOR_VERSION)|g" >> $@
	@echo "s|@MINOR_VERSION@|$(MINOR_VERSION)|g" >> $@
	@echo "s|@FRAMAC_DEFAULT_CPP@|$(FRAMAC_DEFAULT_CPP)|" >> $@
	@echo "s|@FRAMAC_DEFAULT_CPP_ARGS@|$(FRAMAC_DEFAULT_CPP_ARGS)|" >> $@
	@echo "s|@FRAMAC_GNU_CPP@|$(FRAMAC_GNU_CPP)|" >> $@
	@echo "s|@DEFAULT_CPP_KEEP_COMMENTS@|$(DEFAULT_CPP_KEEP_COMMENTS)|" >> $@
	@echo "s|@DEFAULT_CPP_SUPPORTED_ARCH_OPTS@|$(DEFAULT_CPP_SUPPORTED_ARCH_OPTS)|" >> $@

clean:: purge-tests # to be done before a "dune" command
	dune clean
	dune clean --root $(FRAMAC_PTESTS_SRC)
	dune clean --root $(FRAMAC_HDRCK_SRC)
	rm -rf _build .merlin config.sed autom4te.cache

########################################################################
# Makefile.config is rebuilt whenever configure.ac is modified         #
########################################################################

share/Makefile.config: share/Makefile.config.in config.status
	$(PRINT_MAKING) $@
	./config.status --file $@

share/Makefile.dynamic_config: share/Makefile.dynamic_config.internal
	$(PRINT_MAKING) $@
	$(RM) $@
	$(CP) $< $@
	$(CHMOD_RO) $@

config.status: configure
	$(PRINT_MAKING) $@
	./config.status --recheck

configure: configure.ac .force-reconfigure
	$(PRINT_MAKING) $@
	autoconf -f

# If 'make clean' has to be performed after 'git pull':
# change '.make-clean-stamp' before 'git commit'
.make-clean: .make-clean-stamp
	$(TOUCH) $@
	$(QUIET_MAKE) clean

include .make-clean

# force "make clean" to be executed for all users of GIT
force-clean:
	expr `$(CAT) .make-clean-stamp` + 1 > .make-clean-stamp

# force a reconfiguration for all git users
force-reconfigure:
	expr `$(CAT) .force-reconfigure` + 1 > .force-reconfigure


##############################################################################
# INSTALL/UNINSTALL
################################

sinclude config.prefix
FRAMAC_INSTALLDIR?=

INSTALLDIR:=$(FRAMAC_INSTALLDIR)

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

# Ptests needs config.sed so that dune can build Frama-C (if it is not built)
PTEST_DEPS:=config.sed

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
