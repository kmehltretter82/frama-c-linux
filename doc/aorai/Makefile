##############################################################################
#                                                                            #
#  SPDX-License-Identifier LGPL-2.1                                          #
#  Copyright (C)                                                             #
#  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)      #
#  INRIA (Institut National de Recherche en Informatique et en Automatique)  #
#  INSA (Institut National des Sciences Appliquees)                          #
#                                                                            #
##############################################################################

.PHONY: all clean

DWNLDDIR=../manuals
DOCNAME=aorai-manual.pdf
ARCHIVENAME=aorai-example
EXAMPLES=example.c example.ya \
         example_loop.c example_loop.ya \
         README.md

all: main.pdf $(ARCHIVENAME).tar.gz

include ../MakeLaTeXModern

BNF=ya_file.bnf basic_ya.bnf extended_ya.bnf ya_variables.bnf

main.pdf: main.tex $(BNF:.bnf=.tex) macros.tex Schemas/example.pdf
	$(MAKE) $(FRAMAC_MODERN)
	touch main.aux #work around latexmk bug
	latexmk -pdf main.tex

$(ARCHIVENAME).tar.gz: $(addprefix example/, $(EXAMPLES))
	@rm -fr $(ARCHIVENAME)
	@mkdir $(ARCHIVENAME)
	@cp $^ $(ARCHIVENAME)
	@tar czvf $@ $(ARCHIVENAME)

install: main.pdf $(ARCHIVENAME).tar.gz
	mkdir -p ../manuals
	@echo "copying example.tar.gz in ${DWNLDDIR}/$(ARCHIVENAME).tar.gz"
	@rm -f "${DWNLDDIR}/$(ARCHIVENAME).tar.gz"
	@cp $(ARCHIVENAME).tar.gz "${DWNLDDIR}/$(ARCHIVENAME).tar.gz"
	@echo "copying main.pdf    in $(DWNLDDIR)/$(DOCNAME)"
	@rm -f "$(DWNLDDIR)/$(DOCNAME)"
	@cp main.pdf "$(DWNLDDIR)/$(DOCNAME)"

clean:
	@rm -rf *~ *.aux *.log *.nav *.out *.snm *.toc \
		*.mtc* *.maf *.ist *.ilg *.ind \
		*.cm? *.idx *.o pp.ml pp *.dvi *.blg *.bbl \
		main???.png *.image.tex *.haux *.htoc *.html \
		*.backup *.pdf *.backup example/frama_c_journal.ml \
                $(ARCHIVENAME) $(ARCHIVENAME).tar.gz

Schemas/example.pdf: SrcSchemas/example.dot
	mkdir -p Schemas
	dot -Tpdf $< > $@

.SUFFIXES: .tex .bnf .ml .cmo .mll

%.tex: %.bnf transf
	rm -f $@
	./transf $< > $@
	chmod a-w $@

%.ml: %.mll
	ocamllex $<

%.cmo: %.ml
	ocamlc -c $<

transf: transf.cmo
	ocamlc -o $@ $^
