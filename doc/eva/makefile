all: main.pdf

.PHONY: main.pdf

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

clean:
	latexmk -C -bibtex

install:
	rm -f ../manuals/eva-manual.pdf
	cp main.pdf ../manuals/eva-manual.pdf
