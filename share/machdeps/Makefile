##########################################################################
#                                                                        #
#  This file is part of Frama-C.                                         #
#                                                                        #
#  Copyright (C) 2007-2023                                               #
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

update-all: machdep_*.yaml

machdep_avr_16.yaml \
machdep_gcc_x86_32.yaml \
machdep_gcc_x86_64.yaml \
machdep_ppc_32.yaml : \
%.yaml: machdep-schema.yaml make_machdep/make_machdep.py
	@./make_machdep/make_machdep.py -i --from-file $@ --check

machdep_x86_16.yaml machdep_x86_32.yaml machdep_x86_64.yaml: \
machdep_%.yaml: machdep_gcc_%.yaml Makefile
	@sed -e 's/sizeof_fun: .*/sizeof_fun: -1/' \
             -e 's/sizeof_void: .*/sizeof_void: -1/' \
             -e 's/alignof_fun: .*/alignof_fun: -1/' \
             -e 's/compiler: .*/compiler: generic/' \
             $< > $@

machdep_gcc_x86_16.yaml machdep_msvc_x86_64.yaml: %.yaml: machdep-schema.yaml
	@echo "$@ is newer than $< and must be updated manually"
	@exit 1
