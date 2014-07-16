CC=gcc
CFLAGS=-std=c99 -pedantic -Wall -Wno-long-long -Wno-attributes -Wno-unused-but-set-variable -fno-builtin
SHARE=../../share/e-acsl
LIBS=-lgmp -pthread -lcheck -lcheck_pic -lrt -lm
ODIR=obj

_DEPS=e_acsl.h memory_model/e_acsl_bittree.h memory_model/e_acsl_mmodel.h
DEPS=$(patsubst %,$(SHARE)/%,$(_DEPS))

_OBJ=e_acsl.o memory_model/e_acsl_bittree.o memory_model/e_acsl_mmodel.o check_e_acsl_bittree.o
OBJ=$(patsubst %,$(ODIR)/%,$(_OBJ))


run: $(ODIR)/tests.out
	./$(ODIR)/tests.out

$(ODIR)/%.o: $(SHARE)/%.c $(DEPS)
	mkdir -p $(basename $@)
	$(CC) -c -o $@ $< $(CFLAGS) $(LIBS)

$(ODIR)/%.o: %.c $(DEPS)
	$(CC) -c -o $@ $< $(CFLAGS) $(LIBS)

$(ODIR)/tests.out: $(OBJ)
	gcc -o $@ $^ $(LIBS)

.PHONE: clean
clean:
	find obj/ -iname \*.o -delete
