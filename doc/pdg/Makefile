##########################################################################
#                                                                        #
#  SPDX-License-Identifier LGPL-2.1                                      #
#  Copyright (C)                                                         #
#  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  #
#                                                                        #
##########################################################################

.PHONY: all clean

all: main.pdf

GENERATED=biblio.bib
GENERATED+=frama-c-book.cls
include ../MakeLaTeXModern

DWNLDDIR=../manuals
DOCNAME=pdg-documentation-fr.pdf
TEST_DIR=../../plugins/pdg/tests/pdg

BIB_FILE = ../slicing/design-fr/bib-slicing.bib
main.bbl : $(BIB_FILE)
	@echo "=== Fichier .bib plus récent -> effacement du .bbl"
	rm -f $(SRC).bbl

main.pdf: $(FRAMAC_MODERN) $(BIB_FILE) \
	main.tex pdg.tex macros_pdg.tex \
	intro.tex conclusion.tex \
	data.tex ctrl.tex calls.tex utilisation.tex mark.tex impact.tex \
	exple-call.c call-f.pdf call-g.pdf \
	ctrl-dpds.pdf ex-goto.pdf goto.pdf pdg-call.pdf

###############################################################################

GENERATED+=call-f.pdf call-g.pdf
%.pdf : %.dot
	dot -Tpdf $< > $@

GENERATED+=call-f.dot call-g.dot
call-%.dot : $(TEST_DIR)/oracle/call.%.dot
	cp $< $@

call-%.dot :
	@echo
	@echo "ERROR : $@ not found : this file cannot be generated from an oracle of the PDD test 'plugins/pdg/tests/pdg/call.c'"
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
