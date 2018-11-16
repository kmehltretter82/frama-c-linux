
.PHONY: all depend

MODULES= Datatype Primitive Cil Pointer Machine Layout Values Typing Semantics

INCLUDES= -I .
SOURCES=$(addsuffix .v, $(MODULES))
OBJECTS=$(addsuffix .vo, $(MODULES))

all: $(OBJECTS)

.SUFFIXES: .v .vo

.v.vo:
	coqc $(INCLUDES) $<

depend:
	coqdep $(INCLUDES) $(SOURCES) > .depend

clean:
	rm -f *~ *.vo *.glob

sinclude .depend
