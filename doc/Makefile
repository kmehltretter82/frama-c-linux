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

# default when make is invoked without target
default:

FRAMAC_SRC=..
MAKECONFIG_DIR=$(FRAMAC_SRC)/share

include $(FRAMAC_SRC)/share/Makefile.common

FRAMAC_DOCDIR ?= $(PREFIX)/share/doc/frama-c

.PHONY: .force

###################
# Frama-C Version #
###################

VERSION=$(shell $(SED) -e 's/\\(.*\\)/\\1/' $(FRAMAC_SRC)/VERSION)
VERSION_CODENAME=$(shell cat $(FRAMAC_SRC)/VERSION_CODENAME)
VERSION_SAFE=$(subst ~,-,$(VERSION))

ifeq ($(findstring +dev,$(VERSION)),+dev)

# Developpement version, generate the manuals
default: all

else

# Distributed version, download the manuals by default
default: download

MANUALS=acsl

#MANUALS that depend on the frama-c version
VERSIONED_MANUALS=acsl-implementation aorai-manual rte-manual	\
		  wp-manual metrics-manual user-manual		\
		  plugin-development-guide eva-manual

FILES= $(addprefix manuals/, \
	 $(addsuffix -$(VERSION).pdf, $(VERSIONED_MANUALS)) \
         $(addsuffix .pdf, $(MANUALS)) \
	)

download: .force
	$(MKDIR) manuals
	wget -nv -N -P manuals \
	  $(addprefix http://frama-c.com/download/,$(addsuffix -$(VERSION).pdf, $(VERSIONED_MANUALS))) \
	  $(addprefix http://frama-c.com/download/,$(addsuffix .pdf, $(MANUALS)))

install:
	$(MKDIR) $(FRAMAC_DOCDIR)
	$(CP) $(FILES) $(FRAMAC_DOCDIR)

endif


###################
# Generation      #
###################

ifneq ($(NO_SUFFIX),yes)
FC_SUFFIX=-$(VERSION_SAFE)-$(VERSION_CODENAME)
endif

clean::
	$(RM) manuals/*.pdf
	$(RM) manuals/*.tar.gz
	$(MAKE) -C userman clean
	$(MAKE) -C developer dist-clean
	$(MAKE) -C rte clean
	$(MAKE) -C aorai clean
	$(MAKE) -C eva clean
	$(MAKE) -C metrics clean
	$(MAKE) -C ../src/plugins/wp/doc/manual clean

all: \
	manuals/user-manual$(FC_SUFFIX).pdf \
	manuals/plugin-development-guide$(FC_SUFFIX).pdf \
	manuals/rte-manual$(FC_SUFFIX).pdf \
	manuals/aorai-manual$(FC_SUFFIX).pdf \
	manuals/aorai-example$(FC_SUFFIX).tar.gz \
	manuals/hello$(FC_SUFFIX).tar.gz \
	manuals/eva-manual$(FC_SUFFIX).pdf \
	manuals/metrics-manual$(FC_SUFFIX).pdf \
	manuals/wp-manual$(FC_SUFFIX).pdf \

manuals/%:
	mkdir --parent manuals
	$(CP) $< $@

%.pdf:
	$(PRINT) Generating $@
	$(MAKE) -C $(@D) $(@F)

%.tar.gz:
	$(PRINT) Generating $@
	$(MAKE) -C $(@D) $(@F)

manuals/user-manual$(FC_SUFFIX).pdf: userman/userman.pdf
manuals/plugin-development-guide$(FC_SUFFIX).pdf: developer/developer.pdf
manuals/rte-manual$(FC_SUFFIX).pdf: rte/main.pdf
manuals/aorai-manual$(FC_SUFFIX).pdf: aorai/main.pdf
manuals/aorai-example$(FC_SUFFIX).tar.gz: aorai/aorai-example.tar.gz
manuals/hello$(FC_SUFFIX).tar.gz: developer/hello.tar.gz
manuals/eva-manual$(FC_SUFFIX).pdf: eva/main.pdf
manuals/metrics-manual$(FC_SUFFIX).pdf: metrics/metrics.pdf
manuals/wp-manual$(FC_SUFFIX).pdf: ../src/plugins/wp/doc/manual/wp.pdf


###################
# ACSL            #
###################

ifeq ($(wildcard acsl),)

# ACSL and E-ACSL manuals requires a clone of the acsl repository
$(info 'acsl' not in doc; try: git clone https://github.com/acsl-language/acsl.git)

else

ACSL_VERSION=$(shell grep acslversion acsl/version.tex | sed 's/.*{\([^{}\\]*\).*/\1/')
ifneq ($(NO_SUFFIX),yes)
ACSL_SUFFIX=-$(ACSL_VERSION)
endif

clean::
	$(MAKE) -C acsl super-clean

all: \
	manuals/acsl-implementation$(FC_SUFFIX).pdf \
	manuals/acsl$(ACSL_SUFFIX).pdf \

version: manuals/acsl-version.txt

manuals/acsl-implementation$(FC_SUFFIX).pdf: acsl/acsl-implementation.pdf
manuals/acsl$(ACSL_SUFFIX).pdf: acsl/acsl.pdf

manuals/acsl-version.txt:
	echo ${ACSL_VERSION} > $@

###################
# E-ACSL          #
###################

EACSL_DOC=../src/plugins/e-acsl/doc
EACSL_VERSION=$(shell grep 'newcommand{\\eacsllangversion' $(EACSL_DOC)/refman/main.tex | sed 's/.*{\([^{}\\]*\).*/\1/')

ifeq ($(EACSL_VERSION),)

$(info "could not retrieve E-ACSL version from ../src/plugins/e-acsl/doc/refman/main.tex")

else

ifneq ($(NO_SUFFIX),yes)
EACSL_SUFFIX:=-$(EACSL_VERSION)
endif

# Sanity check: version differences between Frama-C, and E-ACSL
ifneq ($(ACSL_VERSION),$(EACSL_VERSION))
    $(info WARNING: different versions for ACSL and E-ACSL manuals: $(ACSL_VERSION) versus $(EACSL_VERSION))
endif

clean::
	$(MAKE) -C $(EACSL_DOC)/refman/ super-clean
	$(MAKE) -C $(EACSL_DOC)/userman/ super-clean

all: \
	manuals/e-acsl-implementation$(FC_SUFFIX).pdf \
	manuals/e-acsl-manual$(FC_SUFFIX).pdf \
	manuals/e-acsl$(EACSL_SUFFIX).pdf

version: manuals/e-acsl-version.txt

manuals/e-acsl-implementation$(FC_SUFFIX).pdf: $(EACSL_DOC)/refman/e-acsl-implementation.pdf
manuals/e-acsl-manual$(FC_SUFFIX).pdf: $(EACSL_DOC)/userman/main.pdf
manuals/e-acsl$(EACSL_SUFFIX).pdf: $(EACSL_DOC)/refman/e-acsl.pdf

manuals/e-acsl-version.txt:
	echo ${EACSL_VERSION} > $@

endif

# Note: The makefiles of ACSL/E-ACSL are not parallelizable when producing both
# acsl.pdf and acsl-implementation.pdf (race conditions in intermediary files,
# leading to non-deterministic errors): we have to wait for one to complete
# before making the other

acsl/acsl-implementation.pdf: | acsl/acsl.pdf
$(EACSL_DOC)/refman/e-acsl-implementation.pdf: | $(EACSL_DOC)/refman/e-acsl.pdf

endif

##############################################################################
# HELP
################################

help::
	@echo "Documentation installation configuration variable"
	@echo "  - PREFIX: by default, documentation will be generated in PREFIX/share/doc/frama-c"
	@echo "  - FRAMAC_DOCDIR: if set, documentation will be in FRAMAC_DOCDIR"
