default: all

EACSL_DIR:=../..
include $(EACSL_DIR)/doc/Makefile.common

##########
# Inputs #
##########

MAIN=main

C_CODE=$(wildcard examples/*.[ci])

DEPS_MODERN=eacslversion.tex biblio.bib macros.tex \
	introduction.tex \
	provides.tex \
	limitations.tex \
	changes.tex \
	$(C_CODE) \
	$(VERSION_FILE)

##############
# Main rules #
##############

.PHONY: all main default
$(MAIN): $(MAIN).pdf
all: $(MAIN)

$(MAIN).pdf: $(DEPS_MODERN) $(FRAMAC_MODERN)

DISTRIB_DIR=$(HOME)/frama-c/doc/www/distrib
install:
	mkdir -p $(EACSL_DIR)/doc/manuals/
	cp -f main.pdf $(EACSL_DIR)/doc/manuals/e-acsl-manual.pdf

.PHONY: clean
clean:
	rm -rf *~ *.aux *.log *.nav *.out *.snm *.toc *.lof *.pp *.bnf \
		*.haux  *.hbbl *.htoc \
                *.cb *.cm? *.bbl *.blg *.idx *.ind *.ilg \
		transf trans.ml pp.ml pp
