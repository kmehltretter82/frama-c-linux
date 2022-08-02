##########################################################################
#                                                                        #
#  This file is part of Frama-C.                                         #
#                                                                        #
#  Copyright (C) 2007-2022                                               #
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
	refman \
	changes
SRC	:= $(addsuffix .tex, $(SRC))
SRC	+= macros.sty

GENERATED= \
	examples/generated/callstack.ml \
	examples/generated/use_callstack.ml \
	examples/generated/syntactic_check.ml
DEPENDENCIES= $(FRAMAC_MODERN) $(GENERATED) frama-c-book.cls

.PHONY: all check check-hello

all: developer.pdf # check << restore check later

# This variable does not exist anymore.
# FC_BINDIR:=$(FRAMAC_ROOT_SRCDIR)/bin
# Thus TODO: use `dune exec -- frama-c` for the following commands

# local plugin.cmi (if any) is in conflict with the one of Frama-C
check: $(GENERATED) check-hello check-examples
	$(ECHO) Checking compilation of example scripts
	$(FC_BINDIR)/frama-c \
		-load-script ./examples/syntactic_check \
		-load-script ./examples/callstack \
		-load-script ./examples/use_callstack \
		-load-script ./examples/acsl_extension_foo \
		-load-script ./examples/acsl_extension_ext_types \
		-load-script ./hello_world/hello_world.ml \
       | tee check.log
	if grep -e "User Error" check.log; then \
           echo "Examples script do not compile with current Frama-C."; \
           echo "Please examine check.log and make appropriate changes"; \
           exit 1; \
        fi
	for i in value value_gui_options visitor ; \
	do $(FC_BINDIR)/frama-c -load-script ./tutorial/viewcfg/generated/$$i/cfg_print.ml ; \
	done
	for i in with_options with_log with_registration ; \
	do $(FC_BINDIR)/frama-c -load-script ./tutorial/hello/generated/$$i/hello_world.ml ; \
	done
	$(ECHO) compilation ok
	$(MAKE) clean-tuto
	PATH=$(FC_BINDIR):$$PATH; $(MAKE) DEVELOPMENT=no PTESTS_OPTS=-error-code -C tutorial/hello/generated/with_test byte opt tests
	$(MAKE) clean-tuto
	PATH=$(FC_BINDIR):$$PATH; $(MAKE) DEVELOPMENT=no PTESTS_OPTS=-error-code -C tutorial/hello/generated/makefile_multiple opt
	$(MAKE) clean-tuto
	PATH=$(FC_BINDIR):$$PATH; $(MAKE) DEVELOPMENT=no PTESTS_OPTS=-error-code -C tutorial/hello/generated/makefile_single opt
	$(MAKE) clean-tuto
	PATH=$(FC_BINDIR):$$PATH; $(MAKE) DEVELOPMENT=no PTESTS_OPTS=-error-code -C tutorial/viewcfg/generated/split opt
	$(MAKE) clean-tuto

check-hello: check-hello-v1 check-hello-v2 check-hello-v3 check-hello-v4 check-hello-v5 check-hello-v6 check-hello-v7

duneb := dune build --root .
dunee := dune exec --root .

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
	(cd tutorial/hello/v6-* && $(duneb) @install && $(duneb) @ptests 2>&1 || true) > checks/hello/v6.res
	diff checks/hello/v6.oracle checks/hello/v6.res

check-hello-v7: check-hello-clean
	#redirect the stderr of 'dune build @doc' because of warnings 'Couldn't find ... Frama_c_kernel__Plugin'
	#checks that a specific generated HTML file exists and contains something related to the source code
	(cd tutorial/hello/v7-* && $(duneb) @install && ($(duneb) @doc 2>/dev/null) && grep -o "welcome message" _build/default/_doc/_html/frama-c-hello/Hello/Hello_options/index.html) 2>&1 > checks/hello/v7.res
	diff checks/hello/v7.oracle checks/hello/v7.res

# For check-examples, we perform no explicit oracle comparisons:
# we simply build the code and run tests (which must always succeed).
check-examples: check-examples-acsl_extension_foo check-examples-acsl_extension_ext_types \
  check-examples-callstack check-examples-syntactic_check

check-examples-clean:
	$(ECHO) Cleaning example files...
	rm -rf examples/*/_build

check-examples-acsl_extension_foo: check-examples-clean
	cd examples/acsl_extension_foo && $(duneb) @install && $(duneb) @ptests

check-examples-acsl_extension_ext_types: check-examples-clean
	cd examples/acsl_extension_ext_types && $(duneb) @install && $(duneb) @ptests

check-examples-callstack: check-examples-clean
	# no test oracles; just check that the code compiles
	cd examples/callstack && $(duneb) @install

check-examples-syntactic_check: check-examples-clean
	cd examples/syntactic_check && $(duneb) @install && $(duneb) @ptests 2>&1


check-all: developer.pdf
	$(MAKE) -C ../.. check-devguide

include ../MakeLaTeXModern

developer.pdf: $(SRC) ../../VERSION $(DEPENDENCIES)
	$(MAKEPDF) developer.tex

install:
	rm -f ../manuals/plugin-development-guide.pdf
	cp developer.pdf ../manuals/plugin-development-guide.pdf

viewcfg: viewcfg-clean viewcfg-v1

viewcfg-clean:
	$(ECHO) Cleaning ViewCfg files...
	rm -rf tutorial/viewcfg/v*/_build

viewcfg-v1:
	cd tutorial/viewcfg/v1 && $(duneb) @install && $(duneb) @ptests

tutorial/viewcfg/generated:
	cd tutorial/viewcfg && make

examples/generated/%.ml: examples/%.ml
	mkdir -p examples/generated
	cp $^ $@
	headache -r $@

archives: FILES=$(shell cd tutorial/hello/v7-doc && git ls-files)

# - use 'git ls-files' to avoid including extraneous files in archive
# - use several tar options to improve build reproducibility
archives:
	export VERSION="$(shell cat ../../VERSION)" && \
	cd tutorial/hello && \
	rm -rf hello-$$VERSION && \
	cp -r v7-doc hello-$$VERSION && \
	tar -cf - $(addprefix hello-$$VERSION/,$(FILES)) \
	  --numeric-owner --owner=0 --group=0 --sort=name \
	  --mtime="$$(date +"%F") Z" --mode='a+rw' | \
	    gzip -9 -n > ../../hello-$$VERSION.tar.gz && \
	rm -rf hello-$$VERSION

.PHONY: tutorial/hello/generated tutorial/viewcfg/generated

###########

clean:
	rm -f *.aux *~ *.log *.blg *.bbl *.toc *.lof *.idx *.ilg *.ind
	rm -rf _whizzy* *.raux *.wdvi *.out
	rm -f *.haux *.htoc
	rm -rf $(GENERATED)

distclean dist-clean: clean
	rm -f $(filter-out mecanism.pdf, $(wildcard *.pdf))
	rm -f *.html
