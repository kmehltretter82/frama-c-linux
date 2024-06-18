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

MANUAL_MACHDEPS=machdep_gcc_x86_16.yaml machdep_msvc_x86_64.yaml

update-all: machdep_*.yaml $(MANUAL_MACHDEPS:%=.%.validated)

machdep_avr_8.yaml \
machdep_avr_16.yaml \
machdep_gcc_x86_32.yaml \
machdep_gcc_x86_64.yaml \
machdep_ppc_32.yaml : \
%.yaml: machdep-schema.yaml make_machdep/make_machdep.py make_machdep/*.c
	@./make_machdep/make_machdep.py -i --from-file $@ --check

machdep_x86_16.yaml machdep_x86_32.yaml machdep_x86_64.yaml: \
machdep_%.yaml: machdep_gcc_%.yaml Makefile
	@sed -e 's/sizeof_fun: .*/sizeof_fun: -1/' \
             -e 's/sizeof_void: .*/sizeof_void: -1/' \
             -e 's/alignof_fun: .*/alignof_fun: -1/' \
             -e 's/compiler: .*/compiler: generic/' \
             -e 's/machdep_name: *machdep_gcc_\([[:alnum:]]*\)/machdep_name: machdep_\1/' \
             -e '/ *__GCC.*/d' -e '/ *__GNU/d' -e '/ *__gnu/d' -e '/ *GXX/d' \
             $< > $@

.%.validated: % machdep-schema.yaml
	@echo "Checking $*"
	@./make_machdep/make_machdep.py --from-file $* --check-only
	@touch $@

.PHONY: check-schema

check-schema:
	@$(foreach machdep, $(wildcard machdep_*.yaml), \
           ./make_machdep/make_machdep.py --from-file $(machdep) --check-only \
           || echo "$(machdep) does not conform to machdep schema";)
