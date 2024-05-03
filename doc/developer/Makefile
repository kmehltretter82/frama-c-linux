##########################################################################
#                                                                        #
#  This file is part of Frama-C.                                         #
#                                                                        #
#  Copyright (C) 2007-2024                                               #
#    CEA (Commissariat à l'énergie atomique et aux énergies              #
#         alternatives)                                                  #
#                                                                        #
#  you can redistribute it and/or modify it under the terms of the GNU   #
#  Lesser General Public License as published by the Free Software       #
#  Foundation, version 2.1.                                              #
#                                                                        #
#  It is distributed in the hope that it will be useful,                 #
#  but WITHOUT ANY WARRANTY; without even the implied warranty of        #
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         #
#  GNU Lesser General Public License for more details.                   #
#                                                                        #
#  See the GNU Lesser General Public License version 2.1                 #
#  for more details (enclosed in the file licenses/LGPLv2.1).            #
#                                                                        #
##########################################################################

include ./Makefile.config

SRC	= developer \
	introduction \
	tutorial \
	architecture \
	advance \
	changes
SRC	:= $(addsuffix .tex, $(SRC))
SRC	+= macros.sty

DEPENDENCIES= $(FRAMAC_MODERN) frama-c-book.cls

.PHONY: all check

all: developer.pdf

# Note: 'check' is not run by default (with make all) because it always
# takes time, and because it requires the 'bogue' opam package

# aliases used when compiling checks
duneb := dune build --root .
dunee := dune exec --root .

check: check-hello check-examples check-viewcfg

check-hello: check-hello-v1 check-hello-v2 check-hello-v3 check-hello-v4 check-hello-v5 check-hello-v6 check-hello-v7

check-hello-clean:
	$(ECHO) Cleaning Hello tutorial files...
	rm -rf tutorial/hello/v*/_build
	rm -rf tutorial/hello/v*/hello.out

check-hello-v1: check-hello-clean
	(cd tutorial/hello/v1-* && $(duneb) && $(dunee) -- frama-c && cat hello.out) 2>&1 > checks/hello/v1.res
	diff checks/hello/v1.oracle checks/hello/v1.res

check-hello-v2: check-hello-clean
	(cd tutorial/hello/v2-* && $(duneb) && $(dunee) -- frama-c -plugins | grep Hello) 2>&1 > checks/hello/v2.res
	diff checks/hello/v2.oracle checks/hello/v2.res

check-hello-v3: check-hello-clean
	(cd tutorial/hello/v3-* && $(duneb) && $(dunee) -- frama-c) 2>&1 > checks/hello/v3.res
	diff checks/hello/v3.oracle checks/hello/v3.res

check-hello-v4: check-hello-clean
	(cd tutorial/hello/v4-* && $(duneb) && $(dunee) -- frama-c -hello) 2>&1 > checks/hello/v4.res
	diff checks/hello/v4.oracle checks/hello/v4.res

check-hello-v5:check-hello-clean
	(cd tutorial/hello/v5-* && $(duneb) && $(dunee) -- frama-c -hello) 2>&1 > checks/hello/v5.res
	diff checks/hello/v5.oracle checks/hello/v5.res

check-hello-v6: check-hello-clean
	(cd tutorial/hello/v6-* && $(duneb) @install && frama-c-ptests >/dev/null && $(duneb) @ptests 2>&1 || true) > checks/hello/v6.res
	diff checks/hello/v6.oracle checks/hello/v6.res

check-hello-v7: check-hello-clean
	#redirect the stderr of 'dune build @doc' because of warnings 'Couldn't find ... Frama_c_kernel__Plugin'
	#checks that a specific generated HTML file exists and contains something related to the source code
	(cd tutorial/hello/v7-* && $(duneb) @install && ($(duneb) @doc 2>/dev/null) && grep -o "welcome message" _build/default/_doc/_html/frama-c-hello/Hello/Hello_options/index.html) 2>&1 > checks/hello/v7.res
	diff checks/hello/v7.oracle checks/hello/v7.res

# For check-examples, we perform no explicit oracle comparisons:
# we simply build the code and run tests (which must always succeed).
check-examples: check-examples-acsl_extension_foo check-examples-acsl_extension_ext_types \
  check-examples-callstack check-examples-syntactic_check check-examples-populate_spec

check-examples-clean:
	$(ECHO) Cleaning example files...
	rm -rf examples/*/_build

check-examples-acsl_extension_foo: check-examples-clean
	cd examples/acsl_extension_foo && $(duneb) @install && frama-c-ptests >/dev/null && $(duneb) @ptests

check-examples-acsl_extension_ext_types: check-examples-clean
	cd examples/acsl_extension_ext_types && $(duneb) @install && frama-c-ptests >/dev/null && $(duneb) @ptests

check-examples-callstack: check-examples-clean
	# no test oracles; just check that the code compiles
	cd examples/callstack && $(duneb) @install

check-examples-syntactic_check: check-examples-clean
	cd examples/syntactic_check && $(duneb) @install && frama-c-ptests >/dev/null && $(duneb) @ptests 2>&1

check-examples-populate_spec: check-examples-clean
	cd examples/populate_spec && $(duneb) @install && frama-c-ptests >/dev/null && $(duneb) @ptests 2>&1

check-all: developer.pdf
	$(MAKE) -C ../.. check-devguide

include ../MakeLaTeXModern

developer.pdf: $(SRC) ../../VERSION $(DEPENDENCIES)
	$(MAKEPDF) developer.tex

install:
	rm -f ../manuals/plugin-development-guide.pdf
	cp developer.pdf ../manuals/plugin-development-guide.pdf

check-viewcfg: check-viewcfg-clean check-viewcfg-v1 check-viewcfg-v2 check-viewcfg-v3 check-viewcfg-v4 check-viewcfg-v5 check-viewcfg-v6

check-viewcfg-clean:
	$(ECHO) Cleaning ViewCfg files...
	rm -rf tutorial/viewcfg/v*/_build

check-viewcfg-v1:
	cd tutorial/viewcfg/v1-* && $(duneb) @install && frama-c-ptests >/dev/null && $(duneb) @ptests

check-viewcfg-v2:
	cd tutorial/viewcfg/v2-* && $(duneb) @install

check-viewcfg-v3:
	cd tutorial/viewcfg/v3-* && $(duneb) @install && frama-c-ptests >/dev/null && $(duneb) @ptests

check-viewcfg-v4:
	cd tutorial/viewcfg/v4-* && $(duneb) @install

check-viewcfg-v5:
	cd tutorial/viewcfg/v5-* && $(duneb) @install

check-viewcfg-v6:
	cd tutorial/viewcfg/v6-* && $(duneb) @install

ifdef NIX_BUILD_TOP
# - in Nix CI we expect the directory to be clean
hello.tar: FILES= $(shell cd tutorial/hello/v7-doc && find *)
else
# - use 'git ls-files' to avoid including extraneous files in archive
hello.tar: FILES= $(shell cd tutorial/hello/v7-doc && git ls-files)
endif
# - use several tar options to improve build reproducibility
hello.tar:
	cd tutorial/hello && \
	rm -rf hello && \
	cp -r v7-doc hello && \
	tar -cf $@ $(addprefix hello/,$(FILES)) \
	  --numeric-owner --owner=0 --group=0 --sort=name \
	  --mtime="$$(date +"%F") Z" --mode='a+rw' && \
	rm -rf hello && \
	mv hello.tar ../../hello.tar

hello.tar.gz: hello.tar
	gzip -9 -ncf hello.tar > hello.tar.gz && \
	rm -rf hello.tar

###########

clean:
	rm -f *.aux *~ *.log *.blg *.bbl *.toc *.lof *.idx *.ilg *.ind
	rm -rf _whizzy* *.raux *.wdvi *.out
	rm -f *.haux *.htoc

distclean dist-clean: clean
	rm -f $(filter-out mecanism.pdf, $(wildcard *.pdf))
	rm -f *.html
