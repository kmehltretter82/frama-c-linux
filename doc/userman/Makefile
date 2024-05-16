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

# Require texi2pdf

.DEFAULT_GOAL := all

include ./Makefile.config
include ../MakeLaTeXModern

TARGET	= userman

###########

.PHONY: all install clean $(TARGET).pdf

ifneq ($(VERBOSEMAKE),no)
  SILENT =
else
  SILENT = -silent
endif

all: $(TARGET).pdf
$(TARGET).pdf: $(TARGET).tex $(FRAMAC_MODERN)
	latexmk $(SILENT) -f -pdf $<

install:
	rm -f ../manuals/user-manual.pdf
	cp $(TARGET).pdf ../manuals/user-manual.pdf

clean:
	latexmk $(SILENT) -C -pdf $(TARGET).tex
