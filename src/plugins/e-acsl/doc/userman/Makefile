default: main.pdf

EACSL_DIR=../..
include $(EACSL_DIR)/doc/Makefile.common

MAIN=main

C_CODE=$(wildcard examples/*.[ci])

DEPS_MODERN=eacslversion.tex biblio.bib macros.tex \
	introduction.tex \
	provides.tex \
	limitations.tex \
	changes.tex \
	$(C_CODE) \
	$(VERSION_FILE)

default: main.pdf

main.pdf: $(DEPS_MODERN)

DISTRIB_DIR=$(HOME)/frama-c/doc/www/distrib
install:
	mkdir -p $(EACSL_DIR)/doc/manuals/
	cp -f main.pdf $(EACSL_DIR)/doc/manuals/e-acsl-manual.pdf
