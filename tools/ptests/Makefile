##########################################################################
#                                                                        #
#  SPDX-License-Identifier LGPL-2.1                                      #
#  Copyright (C)                                                         #
#  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  #
#                                                                        #
##########################################################################

.PHONY: all
all: ptests.exe wtests.exe

.PHONY: ptests.exe
ptests.exe:
	dune build --root . ptests.exe

.PHONY: wtests.exe
wtests.exe:
	dune build --root . wtests.exe

.PHONY: clean
clean: purge-ptests
	dune clean --root .

##########################################################################

TEST_DIRS= nothing cmd

#######

ENV_DIR=../_build/default/ptests/tests

# removes also eventual broken dune files
.PHONY: purge-ptests
purge-ptests:
	@echo "Purge Ptests files"
	find tests -name dune | grep -e "oracle.*/\|result.*/" | xargs --no-run-if-empty rm

.PHONY: %.dune-file
%.dune-file: purge-ptests
	@echo "Dune files for $(basename $@)"
	dune exec --root . ./ptests.exe ./tests/$(basename $@)/tests
	find ./tests/$(basename $@)/tests -name dune -print

.PHONY: dune-files
dune-files: $(addsuffix .dune-file,$(TEST_DIRS))

# note: tests requires the package frama-c (even if frama-c is not used there)
.PHONY: tests
tests: dune-files
	@echo "Run Tests..."
	dune build $(addprefix @tests/,$(addsuffix /tests/ptests,$(TEST_DIRS)))

.PHONY: tests
force-tests: dune-files purge-ptests
	@echo "Run Tests..."
	dune build $(addprefix @tests/,$(addsuffix /tests/ptests,$(TEST_DIRS)))
	@echo "Nb .Log files:"
	find $(ENV_DIR) -name \*.log -print | wc -l
	@echo "Nb .err files:"
	find $(ENV_DIR) -name \*.err -print | wc -l

##########################################################################
