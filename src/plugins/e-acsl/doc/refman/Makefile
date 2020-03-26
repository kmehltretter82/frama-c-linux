##########
# Inputs #
##########

VERSION_FILE=$(wildcard ../../../../../VERSION)
EACSL_VERSION=$(shell cat $(VERSION_FILE))

MAIN=main
DEPS_MODERN=macros_modern.tex eacslversion.tex biblio.bib \
	intro_modern.tex speclang_modern.tex \
	libraries_modern.tex concl_modern.tex changes_modern.tex \
	term_modern.bnf binders_modern.bnf predicate_modern.bnf \
	fn_behavior_modern.bnf oldandresult_modern.bnf \
	loc_modern.bnf memory_modern.bnf list-gram.bnf \
	assertions_modern.bnf loops_modern.bnf st_contracts_modern.bnf \
	logic_modern.bnf data_invariants_modern.bnf model_modern.bnf \
	ghost_modern.bnf generalinvariants_modern.bnf iterator_modern.bnf \
	abrupt_modern.bnf bsearch.c bsearch2.c link.c

##############
# Main rules #
##############

.PHONY: all e-acsl default
default: all
e-acsl: e-acsl-implementation.pdf e-acsl.pdf
all: e-acsl

e-acsl-implementation.pdf: $(DEPS_MODERN)
e-acsl-implementation.tex: $(MAIN).tex Makefile
	rm -f $@
	sed -e '/PrintRemarks/s/%--//' $^ > $@
	chmod a-w $@

e-acsl.pdf: $(DEPS_MODERN)
e-acsl.tex: e-acsl-implementation.tex Makefile
	rm -f $@
	sed -e '/PrintImplementationRq/s/%--//' \
	    -e '/ColorImplementationRq/s/%--//' \
	    $^ > $@
	chmod a-w $@

$(MAIN).pdf: $(DEPS_MODERN)

EACSL_DIR=../..
DISTRIB_DIR=$(HOME)/frama-c/doc/www/distrib
install: e-acsl-implementation.pdf e-acsl.pdf
	mkdir -p $(EACSL_DIR)/doc/manuals
	cp -f $^ $(EACSL_DIR)/doc/manuals

include $(EACSL_DIR)/doc/support/MakeLaTeXModern

eacslversion.tex: Makefile $(VERSION_FILE)
	rm -f $@
	printf '\\newcommand{\\eacslversion}{$(EACSL_VERSION)}' > $@
	chmod a-w $@

.PHONY: clean
clean:
	rm -rf *~ *.aux *.log *.nav *.out *.snm *.toc *.lof *.pp *.bnf \
		*.haux  *.hbbl *.htoc \
                *.cb *.cm? *.bbl *.blg *.idx *.ind *.ilg \
		transf trans.ml pp.ml pp

#########
# Tools #
#########

pp: pp.ml
	ocamlopt -o $@ str.cmxa $^

transf: transf.cmo transfmain.cmo
	ocamlc -o $@ $^

transfmain.cmo: transf.cmo

#################
# Generic rules #
#################

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
