##########################################################################
#                                                                        #
#  This file is part of Frama-C.                                         #
#                                                                        #
#  Copyright (C) 2007-2020                                               #
#    CEA (Commissariat à l'énergie atomique et aux énergies              #
#         alternatives)                                                  #
#                                                                        #
#  All rights reserved.                                                  #
#  Contact CEA LIST for licensing.                                       #
#                                                                        #
##########################################################################

# Example of Makefile for dynamic plugins
#########################################

# Frama-c should be properly installed with "make install" 
# before any use of this makefile

FRAMAC_SHARE  	:=$(shell frama-c-config -print-share-path)
PLUGIN_NAME	= Hello
PLUGIN_CMO	= hello_world
include $(FRAMAC_SHARE)/Makefile.dynamic
