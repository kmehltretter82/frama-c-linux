##########################################################################
#                                                                        #
#  SPDX-License-Identifier LGPL-2.1                                      #
#  Copyright (C)                                                         #
#  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  #
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
