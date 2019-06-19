FRAMAC=../../../../bin/frama-c

TARGETS = \
  simple-main.log \
  global-initial-values.log \
  context-width.log \
  context-depth.1.log \
  context-depth.2.log \
  context-depth.3.log \
  out-of-bound.log \
  widen-hints.log \
  slevel.1.log \
  slevel.2.log \
  nor.1.log \
  nor.2.log \
  ilevel.1.log \
  ilevel.2.log \
	loop-unroll-const.log \
	loop-unroll-nested.log \
	loop-unroll-insuf.log

.SECONDEXPANSION:
.PHONY: all clean

all: $(TARGETS)
clean:
	$(RM) *.log


%.log: SOURCE = $(word 1,$(subst ., ,$*)).c
$(TARGETS) : %.log: $$(SOURCE) $(FRAMAC) $(MAKEFILE_LIST)
	$(FRAMAC) $(FCFLAGS) -val $< > $@

global-initial-values.log: FCFLAGS += -lib-entry
context-depth%.log: FCFLAGS += -lib-entry
context-depth.2.log: FCFLAGS += -context-width 1 -context-depth 1
context-depth.3.log: FCFLAGS += -context-width 1 -context-depth 1 -context-valid-pointers
slevel.1.log: FCFLAGS += -slevel 55
slevel.2.log: FCFLAGS += -slevel 28
ilevel.2.log: FCFLAGS += -val-ilevel 16

nor.1.log nor.2.log: nor.c
	time --format "\nuser time: %Us" $(FRAMAC) $(FCFLAGS) -val $< > $@ 2>&1
nor.1.log: FCFLAGS += -slevel 2001
nor.2.log: FCFLAGS += -slevel 2001 -no-results-function irrelevant_function
