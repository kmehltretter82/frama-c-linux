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

.PHONY: all
all: ptests.exe wtests.exe

.PHONY: ptests.exe
ptests.exe:
	dune build --root . ptests.exe

.PHONY: wtests.exe
wtests.exe:
	dune build --root . wtests.exe

.PHONY: clean
clean: purge-tests
	dune clean --root .

##########################################################################

TEST_DIRS= nothing cmd

#######

ENV_DIR=../_build/default/ptests/tests

# removes also eventual broken dune files
.PHONY: purge-tests
purge-tests:
	@echo "Purge tests"
	find tests -name dune | grep -e "oracle.*/\|result.*/" | xargs --no-run-if-empty rm

.PHONY: clean-tests
clean-tests: purge-tests
	@echo "Clean tests"
	rm -rf $(ENV_DIR)

.PHONY: %.dune-file
%.dune-file: purge-tests
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
force-tests: dune-files clean-tests
	@echo "Run Tests..."
	dune build $(addprefix @tests/,$(addsuffix /tests/ptests,$(TEST_DIRS)))
	@echo "Nb .Log files:"
	find $(ENV_DIR) -name \*.log -print | wc -l
	@echo "Nb .err files:"
	find $(ENV_DIR) -name \*.err -print | wc -l

##########################################################################
