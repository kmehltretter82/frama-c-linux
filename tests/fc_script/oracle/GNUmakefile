# Makefile template for Frama-C/Eva case studies.
# For details and usage information, see the Frama-C User Manual.

### Prologue. Do not modify this block. #######################################
-include path.mk
FRAMAC ?= frama-c
include $(shell $(FRAMAC)-config -print-share-path)/analysis-scripts/prologue.mk
###############################################################################

# Edit below as needed. MACHDEP is mandatory. Suggested flags are optional.

MACHDEP = x86_64

## Preprocessing flags (for -cpp-extra-args)
CPPFLAGS    +=

## General flags
FCFLAGS     += \
  -machdep x86_64 \
  -json-compilation-database . \
  -main eva_main \
  -kernel-warn-key annot:missing-spec=abort \
  -kernel-warn-key typing:implicit-function-declaration=abort \

## Eva-specific flags
EVAFLAGS    += \
  -eva-warn-key builtins:missing-spec=abort \

## GUI-only flags
FCGUIFLAGS +=

## Analysis targets (suffixed with .eva)
TARGETS = fc_script_main.eva

### Each target <t>.eva needs a rule <t>.parse with source files as prerequisites
fc_script_main.parse: \
  fc_stubs.c \
  ../for-find-fun.c \
  ../for-find-fun2.c \
  ../main.c \
  ../main2.c \
  ../main3.c \

### Epilogue. Do not modify this block. #######################################
include $(shell $(FRAMAC)-config -print-share-path)/analysis-scripts/epilogue.mk
###############################################################################
