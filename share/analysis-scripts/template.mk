# TEMPLATE FOR MAKEFILE TO USE IN FRAMA-C/EVA CASE STUDIES

# For details and usage information, see the Frama-C User Manual.

# Do not modify the block below
###############################################################################
-include frama-c-path.mk
FRAMAC ?= frama-c
include $(shell $(FRAMAC)-config -print-share-path)/analysis-scripts/eva-prefix.mk
###############################################################################

# Edit below as needed. Suggested flags are optional.

MACHDEP = x86_32

## Preprocessing flags (for -cpp-extra-args)
CPPFLAGS    +=

## General flags
FCFLAGS     += \
  -kernel-warn-key annot:missing-spec=abort \
  -kernel-warn-key typing:implicit-function-declaration=abort \

## Eva-specific flags
EVAFLAGS    += \
  -eva-warn-key builtins:missing-spec=abort \

## Analysis targets (suffixed with .eva)
TARGETS = main.eva

### Each target <t>.eva needs a rule <t>.parse with source files as prerequisites
main.parse: \
  main.c \

# Do not modify the block below
###############################################################################
include $(shell $(FRAMAC)-config -print-share-path)/analysis-scripts/eva-suffix.mk
###############################################################################
