# This Makefile is included by the template used for analyses with Frama-C/Eva.

# For details and usage information, see the Frama-C User Manual.

# Note: this variable must be defined before including any files
makefile_dir := $(dir $(lastword $(MAKEFILE_LIST)))

## Useful definitions (to be overridden later if needed)

# Improves analysis time, at the cost of extra memory usage
export FRAMA_C_MEMORY_FOOTPRINT = 8

# frama-c-path.mk contains variables which are specific to each
# user and should not be versioned, such as the path to the
# frama-c binaries (e.g. FRAMAC and FRAMAC_GUI).
# It is an optional include, unnecessary if frama-c is in the PATH
-include frama-c-path.mk

# FRAMAC is defined in frama-c-path.mk when it is included, so the
# line below will be safely ignored if this is the case.
# Otherwise, the user may supply it to indicate which Frama-C binary to use.
FRAMAC ?= frama-c

# frama-c.mk contains the main rules and targets
include $(makefile_dir)/frama-c.mk

# Default target
all: eva
ifeq ($(TARGETS),)
	@echo "error: TARGETS is empty"
endif
