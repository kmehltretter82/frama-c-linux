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
include ../MakeLaTeXModern

DWNLDDIR=../manuals
DOCNAME=pdg-documentation-fr.pdf
TEST_DIR=../../tests/pdg

BIB_FILE = ../slicing/bib-slicing.bib
main.bbl : $(BIB_FILE)
	@echo "=== Fichier .bib plus récent -> effacement du .bbl"
	rm -f $(SRC).bbl

main.pdf: $(FRAMAC_MODERN) $(BIB_FILE) \
	main.tex pdg.tex macros_pdg.tex \
	intro.tex conclusion.tex \
	data.tex ctrl.tex calls.tex utilisation.tex mark.tex impact.tex \
	../images/cealistlogo.jpg \
	exple-call.c call-f.pdf call-g.pdf \
	ctrl-dpds.pdf ex-goto.pdf goto.pdf pdg-call.pdf

###############################################################################

GENERATED+=call-f.fig call-g.fig
%.fig : %.dot
	dot -Tfig $< > $@

GENERATED+=call-f.pdf call-g.pdf
%.pdf : %.fig
	fig2dev -L pdf $< $@

GENERATED+=call-f.dot call-g.dot
call-%.dot : $(TEST_DIR)/oracle/call.%.dot
	cp $< $@

call-%.dot :
	@echo
	@echo "ERROR : $@ not found : this file cannot be generated from an oracle of the PDD test 'tests/pdg/call.c'"
	@echo
	exit 1

GENERATED+=exple-call.c
exple-%.c : $(TEST_DIR)/%.c
	sed "1,/BDOC/d" $< > $@

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
