MAIN=main

C_CODE=$(wildcard examples/*.[ci])

DEPS_MODERN=eacslversion.tex biblio.bib macros.tex \
	introduction.tex \
	provides.tex \
	limitations.tex \
	changes.tex \
	$(C_CODE)


default: main.pdf

main.pdf: $(DEPS_MODERN)

EACSL_VERSION= 0.4+dev
FC_VERSION= Neon-20140301

EACSL_DIR=../..
DISTRIB_DIR=$(HOME)/frama-c/doc/www/distrib
install: 
	cp -f main.pdf $(EACSL_DIR)/doc/manuals/e-acsl-manual.pdf
#	cp -f main.pdf \
	  $(DISTRIB_DIR)/download/e-acsl/e-acsl-manual-$(EACSL_VERSION).pdf

include $(EACSL_DIR)/doc/support/MakeLaTeXModern

eacslversion.tex: Makefile
	rm -f $@
	echo '\\newcommand{\\eacslversion}{$(EACSL_VERSION)\\xspace}' > $@
	echo '\\newcommand{\\fcversion}{$(FC_VERSION)\\xspace}' >> $@
	chmod a-w $@

%.1: %.mp
	mpost -interaction=batchmode $<

%.mps: %.1
	mv $< $@

%.pp: %.tex pp
	./pp -utf8 $< > $@

%.pp: %.c pp
	./pp -utf8 -c $< > $@

%.tex: %.ctex pp
	rm -f $@
	./pp $< > $@
	chmod a-w $@

%.bnf: %.tex transf
	rm -f $@
	./transf $< > $@
	chmod a-w $@

%_modern.bnf: %.tex transf
	rm -f $@
	./transf -modern $< > $@
	chmod a-w $@

%.ml: %.mll
	ocamllex $<

%.pdf: %.tex
	pdflatex $*
	makeindex $*
	bibtex $*
	pdflatex $*
	pdflatex $*

%.cmo: %.ml
	ocamlc -c $<

pp: pp.ml
	ocamlopt -o $@ str.cmxa $^

transf: transf.cmo transfmain.cmo
	ocamlc -o $@ $^

transfmain.cmo: transf.cmo

.PHONY: clean

clean:
	rm -rf *~ *.aux *.log *.nav *.out *.snm *.toc *.lof *.pp *.bnf \
		*.haux  *.hbbl *.htoc \
                *.cb* *.cm? *.bbl *.blg *.idx *.ind *.ilg \
		transf trans.ml pp.ml pp
