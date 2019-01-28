GENERATED=main.aux main.cb main.cb2 main.log main.out main.toc main.pdf

all: main

.PHONY: main

include ../MakeLaTeXModern

# by default, the Value manual corresponds to the open-source release
OPENSOURCE?=yes
export OPENSOURCE

main: ../../VERSION *.c
	$(MAKE) $(FRAMAC_MODERN)
	latexmk -pdf main.tex
ifeq ($(OPENSOURCE),no)
	@echo "Generated CLOSED-SOURCE Value manual (OPENSOURCE=$(OPENSOURCE))"
else
	@echo "Generated OPEN-SOURCE Value manual (OPENSOURCE=$(OPENSOURCE))"
endif

clean:
	rm -f $(GENERATED)

install:
	rm -f ../manuals/eva-manual.pdf
	cp main.pdf ../manuals/eva-manual.pdf
