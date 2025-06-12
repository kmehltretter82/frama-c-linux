all: mthread.pdf

.PHONY: mthread.pdf

include ../../MakeLaTeXModern

mthread.pdf:
	$(MAKE) $(FRAMAC_MODERN)
	latexmk -pdf mthread.tex

clean:
	latexmk -C -bibtex

install:
	rm -f ../manuals/mthread-manual.pdf
	cp mthread.pdf ../manuals/mthread-manual.pdf
