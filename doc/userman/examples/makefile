FRAMAC=../../../bin/frama-c

.SECONDEXPANSION:
.PHONY: all clean

all: generated/variadic.c
clean:
	$(RM) *.log generated/*.c

FCFLAGS += -no-autoload-plugins

generated/%.c: %.c $(FRAMAC) $(MAKEFILE_LIST)
	$(FRAMAC) $(FCFLAGS) $< -print -ocode $@
