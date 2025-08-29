##########################################################################
#                                                                        #
#  SPDX-License-Identifier LGPL-2.1                                      #
#  Copyright (C)                                                         #
#  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  #
#                                                                        #
##########################################################################

# Require texi2pdf

.DEFAULT_GOAL := all

include ./Makefile.config
include ../MakeLaTeXModern

TARGET	= userman

###########

.PHONY: all install clean $(TARGET).pdf

ifneq ($(VERBOSEMAKE),no)
  SILENT =
else
  SILENT = -silent
endif

all: $(TARGET).pdf
$(TARGET).pdf: $(TARGET).tex $(FRAMAC_MODERN) examples/*.c examples/*/*.c
	$(MAKE) -C examples
	latexmk $(SILENT) -f -pdf $<

install:
	rm -f ../manuals/user-manual.pdf
	cp $(TARGET).pdf ../manuals/user-manual.pdf

clean:
	latexmk $(SILENT) -C -pdf $(TARGET).tex
