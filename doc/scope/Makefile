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

#vide : pour ne pas utiliser de règles implicites
.SUFFIXE:
.PHONY: clean all debug

all : doc html 

logo-frama-c.eps : ../images/logo.png
	convert $< $@

logo-frama-c.pdf : ../images/logo.png
	convert $< $@

logo-inria-sophia.eps : ../images/logo-inria-sophia.eps
	cp $< $@

logo-inria-sophia.pdf : ../images/logo-inria-sophia.eps
	convert $< $@

# FIGURES_TODO = logo-frama-c logo-inria-sophia

include ../makeLatex

clean : 
