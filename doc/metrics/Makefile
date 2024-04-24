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

.PHONY: default all clean

TARGET = metrics.pdf

all: $(TARGET)
default : all

include ../MakeLaTeXModern

DWNLDDIR=../manuals
DOCNAME=metrics-manual.pdf
RM = rm -Rf

STYLE_FILES = $(FRAMAC_MODERN)
TEXFILES = metrics.tex

EXAMPLE_FILE = tests/metrics/reach.c
$(TARGET): $(STYLE_FILES) $(TEXFILES)

# Hack to get nicer paths (in particular, relative ones)
FCBIN = cd ../.. ; bin/frama-c -no-unicode
FC = $(FCBIN) -metrics -metrics-by-function
LOGDIR = doc/metrics

cil.log:
	$(FC) $(EXAMPLE_FILE) | tee $(LOGDIR)/cil.log
cabs.log:
	$(FC) -metrics-ast cabs $(EXAMPLE_FILE) | tee $(LOGDIR)/cabs.log

cover.log:
	$(FCBIN) -metrics -metrics-eva-cover $(EXAMPLE_FILE) | tee $(LOGDIR)/cover.log

reach.log:
	$(FCBIN) -metrics -metrics-cover main,foo $(EXAMPLE_FILE) | tee $(LOGDIR)/reach.log

%.pdf : %.tex cil.log cabs.log cover.log reach.log ../../VERSION Makefile
	latexmk -silent -pdf $<


install: $(TARGET)
	@echo "Copying $(TARGET) to $(DWNLDDIR)/$(DOCNAME)"
	@rm -f "$(DWNLDDIR)/$(DOCNAME)"
	@cp $(TARGET) "$(DWNLDDIR)/$(DOCNAME)"

clean::
	-$(RM) *~ *.aux *.log *.nav *.out *.snm *.toc *.lof *.pp *.bnf *.pdf *.bbl *.blg *.cb* auto/
	-$(RM) *.log
