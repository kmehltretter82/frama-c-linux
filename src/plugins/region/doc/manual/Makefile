##########################################################################
#                                                                        #
#  This file is part of Region plug-in of Frama-C.                       #
#                                                                        #
#  Copyright (C) 2007-2025                                               #
#    CEA (Commissariat a l'energie atomique et aux energies              #
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
# ---  Region User & Reference Manual                                    ---
# --------------------------------------------------------------------------

.PHONY: all clean install

PLUGIN=region

all: $(PLUGIN).pdf

include ../MakeDoc

IMAGES=

TEX= \
	region.tex \
	region.bib

EXAMPLES=


clean::
	@echo "Cleaning WP"
	rm -f $(LOGS)
	rm -f $(PLUGIN).pdf $(PLUGIN).cb $(PLUGIN).cb2 $(PLUGIN).log $(PLUGIN).out\
		$(PLUGIN).aux $(PLUGIN).blg $(PLUGIN).bbl *~

logs: $(LOGS)
	rm -f $(LOGS) $(PLUGIN).pdf

$(PLUGIN).pdf: $(FRAMAC_DOC) $(TEX) $(LOGS) $(IMAGES) $(EXAMPLES)
	latexmk -pdf $(PLUGIN)

INSTALL_TO=$(FRAMAC_TRUNK)/doc/manuals/$(PLUGIN)-manual.pdf
install:
	rm -f $(INSTALL_TO)
	cp $(PLUGIN).pdf $(INSTALL_TO)
