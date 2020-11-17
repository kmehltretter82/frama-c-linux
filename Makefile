##########################################################################
#                                                                        #
#  This file is part of Frama-C.                                         #
#                                                                        #
#  Copyright (C) 2007-2020                                               #
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

# This file is the main makefile of Frama-C.

FRAMAC_SRC=.
MAKECONFIG_DIR=share

include share/Makefile.common

#Check share/Makefile.config available
ifndef FRAMAC_ROOT_SRCDIR
$(error \
  "You should run ./configure first (or autoconf if there is no configure)")
endif

###################
# Frama-C Version #
###################

VERSION:=$(shell $(CAT) VERSION)
VERSION_CODENAME:=$(shell $(CAT) VERSION_CODENAME)

.PHONY: all

all: config.sed
	dune build @install

ifeq ($(HAS_DOT),yes)
OPTDOT=Some \"$(DOT)\"
else
OPTDOT=None
endif

ifeq ($(HAS_OCAML408),yes)
  DYNLINK_INIT=fun () -> ()
  FORMAT_STAG=stag
  FORMAT_STRING_OF_STAG=match s with \
        Format.String_tag str -> str \
      | _ -> raise (Invalid_argument \"unsupported tag extension\")
  FORMAT_STAG_OF_STRING=Format.String_tag s
  FORMAT_PP_OPT=Format.pp_print_option
  HAS_OCAML407_OR_408=yes
else
  DYNLINK_INIT=Dynlink.init
  FORMAT_STAG=tag
  FORMAT_STRING_OF_STAG=s
  FORMAT_STAG_OF_STRING=s
  ifeq ($(HAS_OCAML407),yes)
    HAS_OCAML407_OR_408=yes
  else
    HAS_OCAML407_OR_408=no
  endif
  FORMAT_PP_OPT=fun ?(none=(fun _ () -> ())) pp fmt o -> \
    match o with \
    | None -> none fmt () \
    | Some v -> pp fmt v
endif

ifeq ($(HAS_OCAML407_OR_408),yes)
  FLOAT_MAX_FLOAT=Float.max_float
else
  FLOAT_MAX_FLOAT=Pervasives.max_float
endif


MAJOR_VERSION=$(shell $(SED) -E 's/^([0-9]+)\..*/\1/' VERSION)
MINOR_VERSION=$(shell $(SED) -E 's/^[0-9]+\.([0-9]+).*/\1/' VERSION)
VERSION_CODENAME=$(shell $(CAT) VERSION_CODENAME)

config.sed: VERSION share/Makefile.config share/Makefile.common Makefile configure.in
	@echo "# generated file" > $@
	@echo "s|@VERSION_CODENAME@|$(VERSION_CODENAME)|" >> $@
	@echo "s|@VERSION@|$(VERSION)|" >> $@
	@echo "s|@CURR_DATE@|$$(LC_ALL=C date)|" >> $@
	@echo "s|@OCAMLC@|$(OCAMLC)|" >> $@
	@echo "s|@OCAMLOPT@|$(OCAMLOPT)|" >> $@
	@echo "s|@WARNINGS@|$(WARNINGS)|" >> $@
	@echo "s|@FRAMAC_DATADIR@|$(FRAMAC_DATADIR)|" >> $@
	@echo "s|@FRAMAC_LIBDIR@|$(FRAMAC_LIBDIR)|" >> $@
	@echo "s|@FRAMAC_ROOT_SRCDIR@|$(FRAMAC_ROOT_SRCDIR)|" >> $@
	@echo "s|@FRAMAC_PLUGINDIR@|$(FRAMAC_PLUGINDIR)|" >> $@
	@echo "s|@FRAMAC_DEFAULT_CPP@|$(FRAMAC_DEFAULT_CPP)|" >> $@
	@echo "s|@FRAMAC_DEFAULT_CPP_ARGS@|$(FRAMAC_DEFAULT_CPP_ARGS)|" >> $@
	@echo "s|@FRAMAC_GNU_CPP@|$(FRAMAC_GNU_CPP)|" >> $@
	@echo "s|@DEFAULT_CPP_KEEP_COMMENTS@|$(DEFAULT_CPP_KEEP_COMMENTS)|" >> $@
	@echo "s|@DEFAULT_CPP_SUPPORTED_ARCH_OPTS@|$(DEFAULT_CPP_SUPPORTED_ARCH_OPTS)|" >> $@
	@echo "s|@OPTDOT@|$(OPTDOT)|" >> $@
	@echo "s|@EXE@|$(EXE)|" >> $@
	@echo "s/@SPLIT_ON_CHAR@/$(SPLIT_ON_CHAR)/g" >> $@
	@echo "s/@STACK_FOLD@/$(STACK_FOLD)/g" >> $@
	@echo "s/@NTH_OPT@/$(NTH_OPT)/g" >> $@
	@echo "s/@FIND_OPT@/$(FIND_OPT)/g" >> $@
	@echo "s/@ASSOC_OPT@/$(ASSOC_OPT)/g" >> $@
	@echo "s/@ASSQ_OPT@/$(ASSQ_OPT)/g" >> $@
	@echo "s/@HAS_YOJSON@/$(HAS_YOJSON)/g" >> $@
	@echo "s|@MAJOR_VERSION@|$(MAJOR_VERSION)|g" >> $@
	@echo "s|@MINOR_VERSION@|$(MINOR_VERSION)|g" >> $@
	@echo "s/@DYNLINK_INIT@/$(DYNLINK_INIT)/g" >> $@
	@echo "s/@FORMAT_STAG@/$(FORMAT_STAG)/g" >> $@
	@echo "s/@FORMAT_STRING_OF_STAG@/$(FORMAT_STRING_OF_STAG)/g" >> $@
	@echo "s/@FORMAT_STAG_OF_STRING@/$(FORMAT_STAG_OF_STRING)/g" >> $@
	@echo "s/@FLOAT_MAX_FLOAT@/$(FLOAT_MAX_FLOAT)/g" >> $@
	@echo "s/@FORMAT_PP_OPT@/$(FORMAT_PP_OPT)/g" >> $@

clean: purge-tests
	dune clean
	dune clean --root ptests
	rm -rf _build .merlin config.sed

########################################################################
# Makefile.config is rebuilt whenever configure.in is modified         #
########################################################################

share/Makefile.config: share/Makefile.config.in config.status
	$(PRINT_MAKING) $@
	./config.status --file $@

share/Makefile.dynamic_config: share/Makefile.dynamic_config.internal
	$(PRINT_MAKING) $@
	$(RM) $@
	$(CP) $< $@
	$(CHMOD_RO) $@

config.status: configure
	$(PRINT_MAKING) $@
	./config.status --recheck

configure: configure.in .force-reconfigure
	$(PRINT_MAKING) $@
	autoconf -f

# If 'make clean' has to be performed after 'git pull':
# change '.make-clean-stamp' before 'git commit'
.make-clean: .make-clean-stamp
	$(TOUCH) $@
	$(QUIET_MAKE) clean

include .make-clean

# force "make clean" to be executed for all users of GIT
force-clean:
	expr `$(CAT) .make-clean-stamp` + 1 > .make-clean-stamp

# force a reconfiguration for all git users
force-reconfigure:
	expr `$(CAT) .force-reconfigure` + 1 > .force-reconfigure


##############################################################################
.PHONY: tests clean-tests run-tests purge-tests

# todo: adds bugs?
# todo: adds crowbar?
# todo: adds dynamic_plugin? No, will be removed from master branch.
# todo: adds fc_script (waiting for a fix in scripts of share/analysis-scripts/)
# todo: adds make_run_script
# todo: adds more_wp?
# todo: adds value/numerors? (requires opam package mlgmpidl and system libraries for MPFR)
# todo: adds verisec
# todo: adds configuration tests related to tests/test_config_apron (and tests/test_config_...) done by the scripts src/plugins/value/vtests and  script src/plugins/value/utests.
# NOTE: the elements of this list shoud be part of the DEFAULT_SUITES contained into `tests/ptest_config`
TESTS=builtins callgraph cil constant_propagation dynamic float idct impact jcdb journal libc metrics misc occurrence pdg pretty_printing rte rte_manual saveload scope slicing sparecode spec syntax test value value/traces
# todo: adds value:apron value:bitwise value:equalities value:gauges values:octagons values:symbols
CONFIGS=

# todo: adds aorai (2 configs + Aorai_test library)
# todo: no test found for studia ?
# todo: adds wp (config qualif)
PLUGIN_TESTS= dive instantiate loop_analysis markdown-report nonterm report server variadic wp
PLUGIN_CONFIGS=

ifneq ($(FRAMAC_WP_CACHEDIR),)
PLUGIN_CONFIGS+= wp:qualif
endif

TEST_CONFIGS=$(sort $(filter-out %:, $(subst :,: ,$(CONFIGS))))

TEST_DIRS=tests
TEST_ALIAS=$(addprefix @tests/, ptests_config $(subst :,/ptests_config_,$(CONFIGS)))

PLUGIN_TEST_DIRS=$(patsubst %,src/plugins/%/tests,$(sort $(filter-out :%,$(subst :, :,$(PLUGIN_TESTS) $(PLUGIN_CONFIGS)))))
PLUGIN_TEST_ALIAS= $(addprefix @src/plugins/,$(addsuffix /tests/ptests_config,$(PLUGIN_TESTS)) $(subst :,/tests/ptests_config_,$(PLUGIN_CONFIGS)))
TEST_DIRS+=$(PLUGIN_TEST_DIRS)
TEST_ALIAS+=$(PLUGIN_TEST_ALIAS)

ptests/ptests.exe: ptests/ptests.ml
	dune build --root ptests ptests.exe

.PHONY: run-tests clean-tests purge-tests tests
purge-tests:
	find $(TEST_DIRS) -name dune | grep -e "oracle.*/\|result.*/" | xargs --no-run-if-empty rm

clean-tests: purge-tests
	rm -rf _build/default/tests

run-tests: FRAMAC_WP_CACHE=replay
run-tests: config.sed purge-tests
	dune exec --root ptests -- ./ptests.exe tests
	for config in $(TEST_CONFIGS); do \
		test -f tests/ptests_$$config || echo "Warning: use default ptests_config (no file: tests/ptests_config_$$config)"; \
		dune exec --root ptests -- ./ptests.exe tests -config $$config; \
	done
	for plugin in $(PLUGIN_TEST_DIRS); do \
		dune exec --root ptests -- ./ptests.exe $$plugin; \
	done
	for plugin in $(PLUGIN_CONFIGS); do \
		plugin_dir=src/plugins/$$(echo $$plugin | sed -e "s/:.*$$//")/tests; \
		config_name=$$(echo $$plugin | sed -e "s/^[^:]*://"); \
		config_file=$$plugin_dir/ptests_config_$$config_name; \
		test -f $$config_file || echo "Warning: use default ptests_config (no file: $$(config_file))"; \
		dune exec --root ptests -- ./ptests.exe $$plugin_dir -config $$config_name; \
	done
	dune build $(TEST_ALIAS)

ifneq ($(FRAMAC_WP_CACHEDIR),)
tests: run-tests
else
tests: run-tests
	@echo "WARNING: cannot run -config qualif tests of WP plugin since FRAMAC_WP_CACHEDIR variable is undefined."
endif

##############################################################################
.PHONY: install uninstall

FRAMAC_INSTALLDIR?=""

install:
ifeq ($(FRAMAC_INSTALLDIR),"")
	dune install
else
	dune install --prefix ${FRAMAC_INSTALLDIR}
	@echo 'DO NOT FORGET TO EXPAND YOUR OCAMLPATH VARIABLE:'
	@echo '  export OCAMLPATH="${FRAMAC_INSTALLDIR}/lib:$$OCAMLPATH"'
endif

uninstall:
ifeq ($(FRAMAC_INSTALLDIR),"")
	dune uninstall
else
	dune uninstall --prefix ${FRAMAC_INSTALLDIR}
endif

###############################################################################
# Local Variables:
# compile-command: "make"
# End:
