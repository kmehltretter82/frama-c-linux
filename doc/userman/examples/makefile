FRAMAC=../../../bin/frama-c

.SECONDEXPANSION:
.PHONY: all clean

all: generated/variadic.c
clean:
	$(RM) *.log generated/*.c

generated/variadic.c: FCFLAGS += -no-autoload-plugins
generated/variadic.c: variadic.c $(FRAMAC) $(MAKEFILE_LIST)
	$(FRAMAC) $(FCFLAGS) $< -print -ocode $@
