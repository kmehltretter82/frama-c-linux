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

.PHONY: all clean

all: main.pdf

GENERATED=biblio.bib
GENERATED+=frama-c-book.cls frama-c-cover.pdf frama-c-left.pdf frama-c-right.pdf
FRAMAC_DOC_ROOT_DIR=../..
include $(FRAMAC_DOC_ROOT_DIR)/MakeLaTeXModern

DWNLDDIR=$(FRAMAC_DOC_ROOT_DIR)/manuals
DOCNAME=slicing-documentation-fr.pdf

BIB_FILE = bib-slicing.bib
main.bbl : $(BIB_FILE)
	@echo "=== Fichier .bib plus récent -> effacement du .bbl"
	rm -f $(SRC).bbl

main.pdf: $(FRAMAC_MODERN) $(BIB_FILE) \
	main.tex macros_slicing.tex slicing.tex \
	intro.tex conclusion.tex \
	fonction.tex interproc.tex interproc2.tex man.tex \
	algo.tex interexples.tex intercmds.tex projets.tex \
	algoH.mli algo.ml \
	call.pdf choose_call.pdf exple2.pdf propagation.pdf propagation.pdf

###############################################################################

GENERATED+=call.pdf choose_call.pdf exple2.pdf propagation.pdf propagation.pdf
%.pdf : %.fig
	fig2dev -L pdf $< $@

###############################################################################

%.pdf: %.tex
	pdflatex $*
	bibtex $*
	pdflatex $*
	pdflatex $*

install: main.pdf
	@echo "copying main.pdf    in $(DWNLDDIR)/$(DOCNAME)"
	@rm -f "$(DWNLDDIR)/$(DOCNAME)"
	@cp main.pdf "$(DWNLDDIR)/$(DOCNAME)"

clean:
	rm -rf *~ *.aux *.log *.nav *.out *.snm *.toc *.lof *.pp *.bnf \
		*.haux  *.hbbl *.htoc \
                *.cb *.cb2 *.cm? *.bbl *.blg *.idx *.ind *.ilg \
		$(GENERATED)

###############################################################################
