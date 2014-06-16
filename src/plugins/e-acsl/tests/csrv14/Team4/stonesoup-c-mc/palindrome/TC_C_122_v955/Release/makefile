# Generic STONESOUP makefile for C test case projects.
#
# Author: John D. Ramsdell (ramsdell)
# Date: 3/20/2012

# Place this in the Release directory of a C test case project.

# This makefile obtains compilation platform information via two
# methods.  When SSTC_INCLUDE is defined, it includes the file named
# by the variable.  The file should be a makefile fragment generated
# using a configure script run on the machine used to compile the
# project.  Otherwise, it obtains information from environment
# variables that begin with SC_, however, the default values should
# work in most cases.

# Ideally, this whole section would be replaced by the include of a
# makefile fragment given by a relative path.  All compilation
# platform specific information would always be maintained at that
# location.

ifdef SSTC_INCLUDE
# Get platform information from makefile fragment
include $(SSTC_INCLUDE)
else
# Otherwise
# Set CC variable
ifdef SS_CC
CC = $(SS_CC)
else
# Use C99 and GCC by default
CC = gcc -std=gnu99
endif
# Set CFLAGS
ifndef SS_CFLAGS
ifndef SS_OS_SPECIFIC_CFLAGS
# Set default c options
CFLAGS = -O0 -fno-stack-protector
else
CFLAGS = $(SS_CFLAGS) $(SS_OS_SPECIFIC_CFLAGS)
endif
else
CFLAGS = $(SS_CFLAGS) $(SS_OS_SPECIFIC_CFLAGS)
endif
# Set linker options
ifndef SS_LDFLAGS
ifndef SS_OS_SPECIFIC_LDFLAGS
# Set default linker options
LDFLAGS = -z execstack
override LDLIBS += -lXtst -lXrandr -lX11 -lssl
else
LDFLAGS = $(SS_LDFLAGS) $(SS_OS_SPECIFIC_LDFLAGS)
endif
else
LDFLAGS = $(SS_LDFLAGS) $(SS_OS_SPECIFIC_LDFLAGS)
endif
ifndef SS_LNK
LD = $(CC)
else
LD = $(SS_LNK)
endif
endif				# ifdef SSTC_INCLUDE

# The program name is derived from the project directory.
PROG := $(notdir $(shell cd ..; pwd))
# Use all the C sources and headers in the ../src directory
OBJS := $(notdir $(patsubst %.c,%.o,$(wildcard ../src/*.c)))
HDRS := $(notdir $(wildcard ../src/*.h))
# You can manually add other programs besides $(PROG) here.
PROGS = $(PROG)

VPATH = ../src

all:	$(PROGS)

clean:
	-rm $(PROGS) $(OBJS)

$(PROG):	$(OBJS)
	$(LD) $(LDFLAGS) -o $(PROG) $(OBJS) $(LDLIBS)

$(OBJS):	$(HDRS)
