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

# Makefile template prologue for Frama-C/Eva case studies.
# For details and usage information, see the Frama-C User Manual.

# Note: this variable must be defined before including any files
makefile_dir := $(dir $(lastword $(MAKEFILE_LIST)))

## Useful definitions (to be overridden later if needed)

# Improves analysis time, at the cost of extra memory usage
export FRAMA_C_MEMORY_FOOTPRINT = 8

# path.mk contains variables which are specific to each
# user and should not be versioned, such as the path to the
# frama-c binaries (e.g. FRAMAC and FRAMAC_GUI).
# It is an optional include, unnecessary if frama-c is in the PATH
-include path.mk

# FRAMAC is defined in path.mk when it is included, so the
# line below will be safely ignored if this is the case.
# Otherwise, the user may supply it to indicate which Frama-C binary to use.
FRAMAC ?= frama-c

# analysis.mk contains the main rules and targets
include $(makefile_dir)/analysis.mk

# Default target
all: eva
