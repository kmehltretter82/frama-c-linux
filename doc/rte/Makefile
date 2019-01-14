.PHONY: all clean

all: main.pdf

include ../MakeLaTeXModern

DWNLDDIR=../manuals
DOCNAME=rte-manual.pdf

main.pdf: $(FRAMAC_MODERN) framacversion.tex \
	main.tex rte.tex \
	biblio.bib \
	stmtannot.c fcontract.c

ifndef FRAMAC_VERSION
FRAMAC_VERSION=$(shell sed -e 's/\\(.*\\)/\\1/' ../../VERSION)
endif

framacversion.tex: ../../VERSION Makefile
	@echo "making version $(FRAMAC_VERSION)"
	rm -f $@
	printf '\\newcommand{\\framacversion}{' > $@
	echo $(FRAMAC_VERSION) >> $@
	echo '}' >> $@
	chmod a-w $@

%.pdf : %.tex
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
		transf trans.ml pp.ml pp
