##########################################################################
#                                                                        #
#  This file is part of WP plug-in of Frama-C.                           #
#                                                                        #
#  Copyright (C) 2007-2023                                               #
#    CEA (Commissariat a l'energie atomique et aux energies              #
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

# --------------------------------------------------------------------------
# ---  WP User & Reference Manual                                        ---
# --------------------------------------------------------------------------

.PHONY: all clean lib

all: wpcoq.pdf 

include ../MakeDoc

SHARE=../../share
COQL=Qedlib Cint Bits Cbits Cfloat Cmath Vset Memory
COQSRC=$(addprefix $(SHARE)/,$(addsuffix .v,$(COQL)))
COQSTY=$(SHARE)/doc/coq2latex.sty
COQTEX=$(SHARE)/doc/coq2latex
TEX= wpcoq.tex qed_generated.tex typed_generated.tex

lib: .lib
.lib: $(COQSRC) $(COQTEX)
	@echo "Importing $(COQL)"
	@$(COQTEX) -o "./%.tex" $(COQSRC)
	@touch .lib

$(COQTEX): $(COQTEX).mll
	make -C $(SHARE) doc/coq2latex

coq2latex.sty: $(COQSTY)
	cp -f $< .

wpcoq.pdf: $(FRAMAC_DOC) $(TEX) .lib coq2latex.sty
	rubber -d wpcoq

clean::
	rm -f .lib $(addsuffix .tex,$(COQL))
