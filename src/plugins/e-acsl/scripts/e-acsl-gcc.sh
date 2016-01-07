##########################################################################
#                                                                        #
#  This file is part of the Frama-C's E-ACSL plug-in.                    #
#                                                                        #
#  Copyright (C) 2012-2015                                               #
#    CEA (Commissariat à l'énergie atomique et aux énergies              #
#         alternatives)                                                  #
#                                                                        #
#  you can redistribute it and/or modify it under the terms of the GNU   #
#  Lesser General Public License as published by the Free Software       #
#  Foundation, version 2.1.                                              #
#                                                                        #
#  It is distributed in the hope that it will be useful,                 #
#  but WITHOUT ANY WARRANTY; without even the implied warranty of        #
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         #
#  GNU Lesser General Public License for more details.                   #
#                                                                        #
#  See the GNU Lesser General Public License version 2.1                 #
#  for more details (enclosed in the file license/LGPLv2.1).             #
#                                                                        #
##########################################################################

#!/bin/sh -e

# Convenience wrapper for small runs of E-ACSL Frama-C plugin

# Print a message to STDERR and exit. If the second argument (exit code)
# is provided and it is '0' then do nothing.
error () {
  if [ -z "$2" ] || ! [ "$2" = 0 ]; then
    echo "e-acsl-gcc: fatal error: $1" 1>&2
    exit 1;
  fi
}

# Check if an executable can be found by in the PATH
has_tool() {
  which "$@" >/dev/null 2>&1 && return 0 || return 1
}

# Abort if a given executable cannot be found in the $PATH
check_tool() {
  has_tool "$1" && echo "$1" \
    || error "Cannot find '$1' executable in the \$PATH"
}

# Getopt options
LONGOPTIONS="help,compile,compile-only,print,debug:,ocode:,oexec:,verbose:, \
  frama-c-only,extra-cpp-args,rtl,frama-c-stdlib,full-mmodel,gmp,quiet,logfile:,
  ld-flags:,cpp-flags:,frama-c-extra:"
SHORTOPTIONS="h,c,C,p,d:,o:,O:,v:,f,E:,R,L,M,l:,e:,g,q,s:,F:"
# Prefix for an error message due to wrong arguments
ERROR="ERROR parsing arguments:"

# Architecture-dependent flags. Since by default Frama-C uses 32-bit
# architecture we need to make sure that same architecture is used for
# instrumentation and for compilation.
MACHDEPFLAGS="`getconf LONG_BIT`"
# -machdep option sent to frama-c
MACHDEP="-machdep gcc_x86_$MACHDEPFLAGS"
# Macro for correct preprocessing of Frama-C generated code
CPPMACHDEP="-D__FC_MACHDEP_X86_$MACHDEPFLAGS"
# GCC machine option
GCCMACHDEP="-m$MACHDEPFLAGS"

# Gcc
CC="`check_tool 'gcc'`"
CFLAGS="-std=c99 $GCCMACHDEP -g3 -O2 -pedantic -fno-builtin -Wall \
    -Wno-long-long \
    -Wno-attributes \
    -Wno-unused-result \
    -Wno-unused-value \
    -Wno-unused-function \
    -Wno-unused-variable \
    -Wno-unused-but-set-variable \
    -Wno-implicit-function-declaration \
    -Wno-attributes"
CPPFLAGS=""
LDFLAGS=""
# Frama-C
FRAMAC="`check_tool 'frama-c'`"
FRAMAC_CONGIG="`check_tool 'frama-c-config'`"
FRAMAC_FLAGS="-implicit-function-declaration ignore"

# E-ACSL source that needed for compilation
FRAMA_C_SHARE="`$FRAMAC_CONGIG -print-share-path`"
EACSL_SHARE="$FRAMA_C_SHARE/e-acsl"
RTL="$EACSL_SHARE/e_acsl.c                      \
  $EACSL_SHARE/memory_model/e_acsl_mmodel.c     \
  $EACSL_SHARE/memory_model/e_acsl_bittree.c    \
"

# CPP and LD flags for compilation of E-ACSL-generated sources
EACSL_CPP_FLAGS="
    -D__FC_errno=(*__errno_location())
    -D__builtin_printf=printf
    -D__builtin_memcpy=memcpy"
EACSL_LD_FLAGS="-lgmp -lm"

# Variables holding getopt options
OPTION_FRAMAC_EXTRA=                     # Extra Frama-C options
OPTION_ECHO="set -x"                     # Echo executed commands to STDOUT
OPTION_INSTRUMENT=1                      # Perform E-ACSL instrumentation
OPTION_PRINT=                            # Output instrumented code
OPTION_DEBUG=                            # Set frama-c debug flag
OPTION_VERBOSE=                          # Set frama-c verbose flag
OPTION_COMPILE=                          # Compile instrumented program
OPTION_OCODE="a.out.frama.c"             # Name of the translated file
OPTION_OEXEC="a.out"                     # Generated executable name
OPTION_EACSL="-e-acsl -then-last"        # Specifies E-ACSL run
OPTION_FRAMA_STDLIB="-no-frama-c-stdlib" # Use Frama-C stdlib
OPTION_FULL_MMODEL=                      # Instrument as much as possible
OPTION_GMP=                              # Use GMP integers everywhere
OPTION_EXTRA_CPP="-I$FRAMA_C_SHARE/libc $CPPMACHDEP" # Extra CPP flags

manpage() {
  echo "NAME"
  echo "  e-acsl-gcc -- convenience wrapper for instrumentation of C files with"
  echo "   the E-ACSL Frama-C plugin and their subsequent compilation using"
  echo "   GNU compiler collection (GCC)"
  echo ""
  echo "SYNOPSIS"
  echo "  e-acsl-gcc <OPTIONS> <C-FILES>"
  echo ""
  echo "OPTIONS"
  echo "  -h, --help"
  echo "      show this help page"
  echo "  -c, --compile"
  echo "      compile generated and original files"
  echo "  -C, --compile-only"
  echo "      compile input files as if they were generated by E-ACSL"
  echo "  -p, --print"
  echo "      output the code generated by E-ACSL to STDOUT"
  echo "  -d, --debug <N>"
  echo "      pass a value to Frama-C -debug option"
  echo "  -o, --ocode <FILENAME>"
  echo "      name of the output source file, defaults to a.out.frama.c"
  echo "  -O, --oexec <FILENAME>"
  echo "      name of the executable generated from the un-instrumented code."
  echo "      Executable compiled from the E-ACSL instrumented sources is"
  echo "      appended .e.acsl suffix. Defaults to a.out and a.out.e-acsl"
  echo "  -v, --verbose <N>"
  echo "      pass a value to Frama-C -verbose option"
  echo "  -f, --frama-c-only"
  echo "      run input source files through Frama-C without E-ACSL"
  echo "  -E, --extra-cpp-args <FLAGS>"
  echo "      pass additional arguments to the Frama-C pre-processor"
  echo "  -R, --rtl"
  echo "      output E_ACSL runtime libraries to STDOUT"
  echo "  -L, --frama-c-stdlib"
  echo "      use Frama-C standard library"
  echo "  -M, --full-mmodel"
  echo "      maximise memory-related instrumentation"
  echo "  -g, --gmp"
  echo "      always use GMP integers instead of C integral types"
  echo "  -l, --ld-flags <FLAGS>"
  echo "      pass the specified flags to the linker"
  echo "  -e, --cpp-flags <FLAGS>"
  echo "      pass the specified flags to the pre-processor (compile-time)"
  echo "  -q, --quiet"
  echo "      suppress any output except for errors and warnings"
  echo "  -s, --logfile <FILE>"
  echo "      redirect all output to a given log file"
  echo "  -F, --frama-c-extra <OPTION>"
  echo "      pass an extra option to frama-c invocation"
  echo ""
  echo "EXAMPLES:"
  echo "  # Instrument foo.c and output the instrumented code to a.out.frama.c"
  echo "      e-acsl-gcc.sh foo.c"
  echo "  # Instrument foo.c, output the instrumented code to gen_foo.c and"
  echo "  # compile foo.c into foo and gen_foo.c into foo.e-acsl"
  echo "      e-acsl-gcc.sh -c -ogen_foo.c -Ofoo foo.c"
  echo "  # Assume gen_foo.c has been instrumented by E-ACSL and compile it"
  echo "  # into a.out.e-acsl"
  echo "      e-acsl-gcc.sh -C gen_foo.c"
  exit 1
}

# See if pygmentize if available for color highlighting and default to plain
# cat command otherwise
if has_tool 'pygmentize'; then
  CAT="pygmentize -g -O style=colorful,linenos=1"
else
  CAT="cat"
fi

# Run getopt
ARGS=`getopt -n "$ERROR" -l "$LONGOPTIONS" -o "$SHORTOPTIONS" -- "$@"`

# Print and exit if getopt fails
if [ $? != 0 ]; then
  exit 1;
fi

# Set all options in $@ before -- and other after
eval set -- "$ARGS"

# Switch statements for other options
for i in $@
do
  case "$i" in
    # Do compile instrumented code
    --help|-h)
      shift;
      manpage;
    ;;
    # Do not echo commands to STDOUT
    # Set log and debug flags to minimal verbosity levels
    --quiet|-q)
      shift;
      OPTION_ECHO=
      OPTION_DEBUG="-debug 0"
      OPTION_VERBOSE="-verbose 0"
    ;;
    # Redirect all output to a given file
    --logfile|-s)
        shift;
        exec > $1
        exec 2> $1
        shift;
    ;;
    # Pass an option to a frama-c invocation
    --frama-c-extra|-F)
        shift;
        OPTION_FRAMAC_EXTRA="$OPTION_FRAMAC_EXTRA $1"
        shift;
    ;;
    # Do compile instrumented code
    --compile|-c)
      shift;
      OPTION_COMPILE=1
    ;;
    # Print the result of instrumenation
    --print|-p)
      shift;
      OPTION_PRINT=1
    ;;
    # Set Frama-C debug flag
    --debug|-d)
      shift;
      if [ "$1" -eq "$1" ] 2>/dev/null; then
        OPTION_DEBUG="-debug $1"
      else
        error "-d|--debug option requires integer argument"
      fi
      shift;
    ;;
    # Set Frama-C verbose flag
    --verbose|-v)
      shift;
      if [ "$1" -eq "$1" ] 2>/dev/null; then
        OPTION_VERBOSE="-verbose $1"
      else
        error "-v|--verbose option requires integer argument"
      fi
      shift;
    ;;
    # Specify the name of the default source file where instrumented
    # code is to be written
    --ocode|-o)
      shift;
      OPTION_OCODE="$1"
      shift
    ;;
    # Specify the base name of the executable generated from the
    # instrumented and non-instrumented sources.
    --oexec|-O)
      shift;
      OPTION_OEXEC="$1"
      shift
    ;;
    # Additional CPP arguments
    --extra-cpp-args|-E)
      shift;
      OPTION_EXTRA_CPP="$OPTION_EXTRA_CPP$1"
      shift;
    ;;
    # Additional flags passed to the linker
    --ld-flags|-l)
      shift;
      LDFLAGS="$LDFLAGS $1"
      shift;
    ;;
    # Additional flags passed to the pre-processor (compile-time)
    --cpp-flags|-e)
      shift;
      CPPFLAGS="$CPPFLAGS $1"
      shift;
    ;;
    # Do not perform the instrumentation, only compile the provided sources
    # This option assumes that the source files provided at input have
    # already been instrumented
    --compile-only|-C)
      shift;
      OPTION_INSTRUMENT=
      OPTION_COMPILE="1"
    ;;
    # Run only frama-c related instrumentation
    --frama-c-only|-f)
      shift;
      OPTION_EACSL=
    ;;
    # Output the RTL files
    --rtl|-R)
      echo $RTL
      exit 0;
    ;;
    # Do use Frama-C stdlib, which is the default behaviour of Frama-C
    --frama-c-stdlib|-L)
      shift;
      OPTION_FRAMA_STDLIB=""
    ;;
    # Use as much memory-related instrumentation as possible
    -M|--full-mmodel)
      shift;
      OPTION_FULL_MMODEL="-e-acsl-full-mmodel"
    ;;
    # Use GMP everywhere
    -g|--gmp)
      shift;
      OPTION_GMP="-e-acsl-gmp-only"
    ;;
  esac
done
shift;

# Bail if no files to translate are given
if test -z "$1"; then
  error "no input files";
fi

# Instrument
if [ -n "$OPTION_INSTRUMENT" ]; then
  ($OPTION_ECHO; \
    $FRAMAC \
    $FRAMAC_FLAGS \
    $MACHDEP \
    $OPTION_FRAMAC_EXTRA \
    -cpp-extra-args="$OPTION_EXTRA_CPP" \
    -e-acsl-share $EACSL_SHARE \
    $OPTION_VERBOSE \
    $OPTION_DEBUG \
    $OPTION_FRAMA_STDLIB \
    $OPTION_FULL_MMODEL \
    $OPTION_GMP \
    "$@" \
    $OPTION_EACSL \
    -print \
    -ocode "$OPTION_OCODE");
    error "aborted by frama-c" $?;
  # Print translated code
  if [ -n "$OPTION_PRINT" ]; then
    $CAT $OPTION_OCODE
  fi
fi

# Compile
if test -n "$OPTION_COMPILE"  ; then
  # Compile the original files only if the instrumentation option is given,
  # otherwise the provided sources are assumed to be E-ACSL instrumented files
  if [ -n "$OPTION_INSTRUMENT" ]; then
    ($OPTION_ECHO; $CC $CPPFLAGS $CFLAGS "$@" -o "$OPTION_OEXEC" $LDFLAGS);
    error "fail to compile/link un-instrumented code: $@" $?;
  else
    OPTION_OCODE="$@"
  fi
  # Compile and link E-ACSL-instrumented file
  ($OPTION_ECHO; $CC $CPPFLAGS $CFLAGS $EACSL_CPP_FLAGS $RTL \
    "$OPTION_OCODE" -o "$OPTION_OEXEC.e-acsl" $LDFLAGS $EACSL_LD_FLAGS)
  error "fail to compile/link instrumented code: $@" $?;
fi
exit 0;
