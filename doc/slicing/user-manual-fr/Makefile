##########################################################################
#                                                                        #
#  SPDX-License-Identifier LGPL-2.1                                      #
#  Copyright (C)                                                         #
#  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  #
#                                                                        #
##########################################################################

.PHONY: all clean

all: main.pdf

GENERATED=
GENERATED+=frama-c-book.cls
FRAMAC_DOC_ROOT_DIR=../..
include $(FRAMAC_DOC_ROOT_DIR)/MakeLaTeXModern

DWNLDDIR=$(FRAMAC_DOC_ROOT_DIR)/manuals
DOCNAME=slicing-user-manual-fr.pdf

main.pdf: $(FRAMAC_MODERN) \
	main.tex slicing.tex

###############################################################################

%.pdf: %.tex
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
