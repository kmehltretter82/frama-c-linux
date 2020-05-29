# This Makefile is included by the template used for analyses with Frama-C/Eva.

# For details and usage information, see the Frama-C User Manual.

# Some targets provided for convenience
# Note: they all depend on TARGETS having been properly set by the user
eva: $(TARGETS)
parse: $(TARGETS:%.eva=%.parse)
# Opening one GUI for each target is cumbersome; we open only the first target
gui: $(firstword $(TARGETS)).gui
