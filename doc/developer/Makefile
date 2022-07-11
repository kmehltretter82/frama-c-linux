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

GENERATED= tutorial/viewcfg/generated \
	tutorial/hello/generated \
	examples/generated/callstack.ml \
	examples/generated/use_callstack.ml \
	examples/generated/syntactic_check.ml
DEPENDENCIES= $(FRAMAC_MODERN) $(GENERATED) frama-c-book.cls

.PHONY: all check

all: developer.pdf # check << restore check later

FC_BINDIR:=$(FRAMAC_ROOT_SRCDIR)/bin

.PHONY: clean-tuto
clean-tuto:
	$(RM) ../../lib/plugins/META.frama-c-hello ../../lib/plugins/META.frama-c-viewcfg
	$(RM) ../../lib/plugins/top/Hello.* ../../lib/plugins/top/Viewcfg.*

# local plugin.cmi (if any) is in conflict with the one of Frama-C
check: $(GENERATED)
	$(MAKE) clean-tuto
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

check-all: developer.pdf
	$(MAKE) -C ../.. check-devguide

include ../MakeLaTeXModern

developer.pdf: $(SRC) ../../VERSION $(DEPENDENCIES)
	$(MAKEPDF) developer.tex

install:
	rm -f ../manuals/plugin-development-guide.pdf
	cp developer.pdf ../manuals/plugin-development-guide.pdf

tutorial/hello/generated:
	cd tutorial/hello && make

tutorial/viewcfg/generated:
	cd tutorial/viewcfg && make

examples/generated/%.ml: examples/%.ml
	mkdir -p examples/generated
	cp $^ $@
	headache -r $@

archives: tutorial/hello/generated
	cd tutorial/hello/generated/; \
	  mv with_doc/ hello-$(VERSION)/; \
	  tar -zcvf ../../../hello-$(VERSION).tar.gz hello-$(VERSION)/*; \
	  mv hello-$(VERSION)/ with_doc/

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
