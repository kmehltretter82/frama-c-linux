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

.PHONY: all pdf clean install

all: pdf

PLUGIN=region

include ../MakeDoc

clean::
	@echo "Cleaning WP"
	rm -f $(PLUGIN).pdf $(PLUGIN).cb $(PLUGIN).cb2 $(PLUGIN).log $(PLUGIN).out\
		$(PLUGIN).aux $(PLUGIN).blg $(PLUGIN).bbl *~

TEX_FILES=$(shell find . -name "*.tex")

pdf: $(TEX_FILES) $(FRAMAC_DOC) VERSION VERSION_CODENAME
	latexmk -pdf $(PLUGIN)

rebuild:
	rm -f $(PLUGIN).pdf
	latexmk -pdf $(PLUGIN)


TARGET=$(FRAMAC_TRUNK)/doc/manuals/$(PLUGIN)-manual.pdf
install:
	rm -f $(TARGET)
	cp $(PLUGIN).pdf $(TARGET)
