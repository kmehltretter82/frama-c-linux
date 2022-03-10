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
# TESTING
################################

# Defines where to find the ptest_config file
PURGED_PTEST_DIRS?=tests $(wildcard src/plugins/*/tests)
PTEST_OPTS?=
PTEST_DIRS?=$(PURGED_PTEST_DIRS)

# Defines the related dune targets
PTEST_ALIASES=$(addsuffix /ptests,$(addprefix @, tests src/plugins))
# TODO: uncomments when a dune file is at least generated for all PTEST_DIRS
#PTEST_ALIASES=$(addsuffix /ptests,$(addprefix @,$(PTEST_DIRS)))

.PHONY: tests.info
tests.info:
	echo "PURGED_PTEST_DIRS=$(PURGED_PTEST_DIRS)"
	echo "PTEST_DIRS=$(PTEST_DIRS)"
	echo "PTEST_OPTS=$(PTEST_OPTS)"
	echo "PTEST_ALIASES=$(PTEST_ALIASES)"

# Note: the public name of ptest.exe is frama-c-ptests
ptests/ptests.exe: ptests/ptests.ml
	dune build --root ptests ptests.exe

# Note: the public name of wtest.exe is frama-c-wtests
ptests/wtests.exe: ptests/wtests.ml
	dune build --root ptests wtests.exe

# Command for executing ptest (in order to generate dune test files)
PTESTS=dune exec --root ptests -- frama-c-ptests
#PTESTS=dune exec --root ptests -- frama-c-ptests -v

.PHONY: ptests-help
ptests-help:
	$(PTESTS) --help

# Note: wrapper that can be used during dune testing (c.f. frama-c-ptests)
WTESTS=dune exec --root ptests -- frama-c-wtests

.PHONY: wtests-help
wtests-help:
	$(WTESTS) --help

# Removes all dune files generated for testing: xargs -n 10 avoids a too long line
.PHONY: purge-tests
purge-tests:
	find $(PURGED_PTEST_DIRS) -name dune | grep -e "/oracle.*/dune\|/result.*/dune" | xargs --no-run-if-empty -n 10 rm

# Force the full cleaning of the testing environment
.PHONY: clean-tests
clean-tests: purge-tests
	rm -rf $(addprefix _build/default/,$(PURGED_PTEST_DIRS))

# Generates all dune files used for testing
.PHONY: run-ptests
run-ptests: config.sed purge-tests ptests/ptests.exe ptests/wtests.exe
	$(PTESTS) $(PTEST_OPTS) $(PTEST_DIRS)

.PHONY: run-ptests.replay
run-ptests.replay: config.sed ptests/ptests.exe
	$(PTESTS) $(PTEST_OPTS) $(PTEST_DIRS)

# Run tests of for all configurations (and build all dune files)
.PHONY: run-tests
run-tests: FRAMAC_WP_CACHE=replay
run-tests: run-ptests
	dune build $(PTEST_ALIASES)

# Replay tests of for all configurations (requires  all dune files)
.PHONY: test.replay
tests.replay: FRAMAC_WP_CACHE=replay
tests.replay: config.sed
	dune build $(PTEST_ALIASES)

# Update cache entries of for all configurations (requires all dune files)
.PHONY: tests.update-wp-cache
tests.update-wp-cache: FRAMAC_WP_CACHE=update
tests.update-wp-cache: config.sed
	dune build $(PTEST_ALIASES)

.PHONY: tests
ifneq ($(FRAMAC_WP_CACHEDIR),)
tests: run-tests
else
tests: run-tests
	@echo "WARNING: cannot run -config qualif tests of WP plugin since FRAMAC_WP_CACHEDIR variable is undefined."
endif

##############################################################################
# INSTALL/UNINSTALL
################################
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

################################
# Code prettyfication and lint #
################################

# We're interested by any .ml[i]? file in src, except for scripts in test
# directories, and generated files (in particular lexers and parsers)
# Note: the find command below is *very* ugly, but it should be POSIX-compliant.

ALL_ML_FILES:=$(shell find src -name '*.ml' -print -o -name '*.mli' -print -o -path '*/tests' -prune '!' -name '*')
ALL_ML_FILES+=ptests/ptests.ml

ifeq ($(origin MANUAL_ML_FILES),undefined)
MANUAL_ML_FILES:=$(ALL_ML_FILES)
endif

MANUAL_ML_FILES:=\
  $(filter-out $(GENERATED) $(PLUGIN_GENERATED_LIST), $(MANUAL_ML_FILES))

# Allow control of files to be linted/fixed by external sources
# (e.g. pre-commit hook that will concentrate on files which have changed)

sinclude .Makefile.lint

HAS_GIT_FILE:=$(wildcard .git/HEAD)

ifeq ("$(HAS_GIT_FILE)","")
LINT_OTHER_SOURCES:=
else
LINT_OTHER_SOURCES:=\
  $(filter-out \
    $(shell git ls-tree --name-only HEAD src/plugins/*), \
    $(wildcard src/plugins/*))
endif

$(foreach dir,$(LINT_OTHER_SOURCES),$(eval sinclude $(dir)/.Makefile.lint))

ML_LINT_MISSING:=$(filter-out $(MANUAL_ML_FILES), $(ML_LINT_KO))

# By default, also checks files with unknown status:
# this requires new files to pass lint checker from the beginning

ML_LINT_CHECK?=$(filter-out $(ML_LINT_KO), $(MANUAL_ML_FILES))

# this NEWLINE variable containing a literal newline character is used to avoid
# the error "argument list too long", in some instances of "foreach".
# For details, see https://stackoverflow.com/questions/7039811
define NEWLINE


endef

# pre-requisite intentionally left blank: this target should only be used
# if the file is not present to generate it once and forall,
# and be edited manually afterwards
# double colon here tells make not to attempt updating the .Makefile.lint
# if it does not exist, but just to ignore it.
.Makefile.lint::
	echo "ML_LINT_KO:=" >> $@
	$(foreach file,$(sort $(MANUAL_ML_FILES)), \
            if ! $(MAKE) ML_LINT_CHECK=$(file) lint; \
            then echo "ML_LINT_KO+=$(file)" >> $@; fi;$(NEWLINE) )

$(foreach dir,$(LINT_OTHER_SOURCES),\
  $(eval $(dir)/.Makefile.lint:: ; \
     $(foreach file, $(sort $(filter $(dir)/%, $(MANUAL_ML_FILES))), \
            if ! $$(MAKE) ML_LINT_CHECK=$(file) lint; \
            then echo "ML_LINT_KO+=$(file)" >> $$@; fi; )))

.PHONY: stats-lint
stats-lint:
	echo \
         "scale = 2; bad = $(words $(ML_LINT_MISSING)); \
          all = $(words $(sort $(MANUAL_ML_FILES))); \
	  fail = $(words $(ML_LINT_KO)); \
          \"lint coverage: \"; \
          ((all - fail) * 100) / all; " | bc
	echo "number of files supposed to pass lint: $(words $(ML_LINT_CHECK))"
	echo "number of files supposed to fail lint: $(words $(ML_LINT_KO))"
ifneq ($(strip $(ML_LINT_MISSING)),)
	echo "number of files missing from src/ : $(words $(ML_LINT_MISSING))"
	$(foreach file, $(ML_LINT_MISSING), echo $(file);)
	exit 1
endif

INDENT_TARGET= $(patsubst %,%.indent,$(ML_LINT_CHECK))

LINT_TARGET= $(patsubst %,%.lint,$(ML_LINT_CHECK))

FIX_SYNTAX_TARGET=$(patsubst %,%.fix-syntax,$(ML_LINT_CHECK))

.PHONY: $(INDENT_TARGET) $(LINT_TARGET) $(FIX_SYNTAX_TARGET) \
        indent lint fix-syntax

indent: $(INDENT_TARGET)

lint:: $(LINT_TARGET)

check-ocp-indent-version:
	if command -v ocp-indent >/dev/null; then \
		if [ -z "$(shell ocp-indent --version)" ]; then echo "warning: ocp-indent returned an empty string, assuming it is the correct version"; \
		else \
			$(eval ocp_version_major := $(shell ocp-indent --version | $(SED) -E "s/^([0-9]+)\.[0-9]+\..*/\1/")) \
			$(eval ocp_version_minor := $(shell ocp-indent --version | $(SED) -E "s/^[0-9]+\.([0-9]+)\..*/\1/")) \
			if [ "$(ocp_version_major)" -lt 1 -o "$(ocp_version_minor)" -lt 7 ]; then \
				echo "error: ocp-indent 1.7.0 required for linting (got $(ocp_version_major).$(ocp_version_minor))"; \
			exit 1; \
			fi; \
		fi; \
	else \
		exit 1; \
	fi;

fix-syntax: $(FIX_SYNTAX_TARGET)

$(INDENT_TARGET): %.indent: % check-ocp-indent-version
	ocp-indent -i $<

$(LINT_TARGET): %.lint: % check-ocp-indent-version
	# See SO 1825552 on mixing grep and \t (and cry)
	# For OK_NL, we have three cases:
	# - for empty files, the computation boils down to 0 - 0 == 0
	# - for non-empty files with a proper \n at the end, to 1 - 1 == 0
	# - for empty files without \n, to 1 - 0 == 1 that will be catched
	OK_TAB=$$(grep -c -e "$$(printf '^ *\t')" $<) ; \
        OK_SPACE=$$(grep -c -e '[[:blank:]]$$' $<) ; \
        OK_NL=$$(($$(tail -c -1 $< | wc -c) - $$(tail -n -1 $< | wc -l))) ; \
        OK_EMPTY=$$(tail -n -1 $< | grep -c -e '^[[:blank:]]*$$') ; \
        ERROR=$$(($$OK_TAB + $$OK_SPACE + $$OK_NL + $$OK_EMPTY)) ; \
        if test $$ERROR -gt 0; then \
          echo "File $< does not pass syntactic checks:"; \
          echo "$$OK_TAB lines indented with tabulation instead of spaces"; \
          echo "$$OK_SPACE lines with spaces at end of line"; \
          test $$OK_NL -eq 0 || echo "No newline at end of file"; \
          test $$OK_EMPTY -eq 0 || echo "Empty line(s) at end of file"; \
          echo "Please run make ML_LINT_CHECK=$< fix-syntax"; \
          exit 1 ; \
        fi
	ocp-indent $< > $<.tmp;
	if cmp -s $< $<.tmp; \
        then rm -f $<.tmp; \
        else \
          echo "File $< is not indented correctly."; \
          echo "Please run make ML_LINT_CHECK=$< indent";\
          rm $<.tmp; \
          exit 1; \
        fi

$(FIX_SYNTAX_TARGET): %.fix-syntax: %
	$(ISED) -e 's/^ *\t\+/ /' $<
	$(ISED) -e 's/\(.*[^[:blank:]]\)[[:blank:]]\+$$/\1/' $<
	$(ISED) -e 's/^[ \t]\+$$//' $<
	if test \( $$(tail -n -1 $< | wc -l) -eq 0 \) -a \( $$(wc -c $< | cut -d " " -f 1) -gt 0 \) ; then \
          echo "" >> $<; \
        else \
          while tail -n -1 $< | grep -l -e '^[ \t]*$$'; do \
            head -n -1 $< > $<.tmp; \
            mv $<.tmp $<; \
          done; \
        fi

# Avoid a UTF-8 locale at all cost: in such setting, sed does not work
# reliably if you happen to have latin-1 encoding somewhere,
# which is still unfortunately the case in some dark corners of the platform
%.fix-syntax: LC_ALL = C


###############################################################################
# Local Variables:
# compile-command: "make"
# End:
