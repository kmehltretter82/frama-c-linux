all: main.pdf mthread.pdf

.PHONY: main.pdf mthread.pdf

include ../MakeLaTeXModern

# by default, the Eva manual corresponds to the open-source release
OPENSOURCE?=yes
export OPENSOURCE

main.pdf: ../../VERSION examples/**.c
	$(MAKE) -C examples/parametrizing
	$(MAKE) $(FRAMAC_MODERN)
	latexmk -pdf main.tex
ifeq ($(OPENSOURCE),no)
	@echo "Generated CLOSED-SOURCE Eva manual (OPENSOURCE=$(OPENSOURCE))"
else
	@echo "Generated OPEN-SOURCE Eva manual (OPENSOURCE=$(OPENSOURCE))"
endif

mthread.pdf: ../../VERSION ../../VERSION_CODENAME examples/mthread/**.c
	$(MAKE) -C examples/mthread
	$(MAKE) $(FRAMAC_MODERN)
	latexmk -pdf mthread/mthread.tex
	@echo "Generated Mthread manual"

clean:
	latexmk -C -bibtex
	latexmk -C -bibtex mthread/mthread.tex
	$(MAKE) -C examples/parametrizing clean
	$(MAKE) -C examples/mthread clean

install:
	rm -f ../manuals/eva-manual.pdf
	rm -f ../manuals/mthread-manual.pdf
	cp main.pdf ../manuals/eva-manual.pdf
	cp mthread.pdf ../manuals/mthread-manual.pdf
