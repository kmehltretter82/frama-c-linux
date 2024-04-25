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

MAKECONFIG_DIR=../../../share
include $(MAKECONFIG_DIR)/Makefile.common
include $(MAKECONFIG_DIR)/Makefile.generic

DEPENDENCIES= $(FRAMAC_MODERN) \
	frama-c-book.cls

.PHONY: check-depend clean all

all:  check_and_compare main.idx
	./check_and_compare

main.idx: ../developer.idx $(wildcard ../*.tex)
	cp ../developer.idx main.idx

check_and_compare: check_index_grammar.cmi check_index_lexer.cmi check_index_grammar.cmx \
	     	check_index_lexer.cmx check_and_compare.cmx 
	$(OCAMLOPT) -o check_and_compare str.cmxa check_index_grammar.cmx \
	        check_index_lexer.cmx check_and_compare.cmx 

clean:
	$(RM) *.cm*
	$(RM) check_index_*.ml
	$(RM) check_index_grammar.mli
	$(RM) *.o
	$(RM) *.output
	$(RM) check_code.annot
	$(RM) check_and_compare
	$(RM) code_file index_file summary.txt

.depend check-depend: check_index_grammar.ml check_index_lexer.ml
	ocamldep *.ml > .depend

include .depend
