##########################################################################
#                                                                        #
#  This file is part of the Frama-C's E-ACSL plug-in.                    #
#                                                                        #
#  Copyright (C) 2012-2016                                               #
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

# Check whether the first line reported by running command $1 has an identifier
# specified by $2. E.g., check whether readlink used by the script is GNU and
# getopt comes from util-linux.
required_tool() {
  "$1" --version 2>&1 | head -1 | grep "$2" > /dev/null
  error "$1 is not $2" $?
}

# Check if a given executable name can be found by in the PATH
has_tool() {
  which "$@" >/dev/null 2>&1 && return 0 || return 1
}

# Check if a given executable name is indeed an executable or can be found
# in the $PATH. Abort the execution if not.
check_tool() {
   { has_tool "$1" || test -e "$1"; } || error "No executable $1 found";
}

# build and output option string for RTE plugin based on a comma-delimited
# option string
rte_options() {
  local optstring="$1"
  local start="-rte -rte-warn"
  local opts="-rte-no-all"
  # RTE integer overflow options coming from Frama-C, presently
  # they are enabled by default, so they should be negated
  local intopts="-no-warn-signed-overflow -no-warn-unsigned-overflow"
  local vopts="mem,int,float,div,ret,precond,shift,all"
  local all=""

  for opt in $(echo $optstring | tr ',' ' '); do
    case $opt in
      mem) # valid pointer or array access
        opts="$opts -rte-mem"
      ;;
      int) # integer overflows
        intopts="-warn-signed-overflow -warn-unsigned-overflow"
      ;;
      float) # casts from floating-point to integer
        opts="$opts -rte-float-to-int"
      ;;
      div) # division by zero
        opts="$opts -rte-div"
      ;;
      ret) # return
      ;;
      precond) # function calls based on contracts
        opts="$opts -rte-precond"
      ;;
      shift) # left and right shifts by a value out of bounds
        opts="$opts -rte-shift"
      ;;
      all) # all assertions
        all=1
      ;;
      *)
        return 1;
      ;;
    esac
  done

  if [ -n "$all" ]; then
    echo $start -rte-all -then
  else
    echo $start $opts $intopts -then
  fi
  return 0;
}

# Check if the following tools are GNU and abort otherwise
required_tool getopt "util-linux"
required_tool readlink "GNU coreutils"
required_tool find "GNU findutils"

# Getopt options
LONGOPTIONS="help,compile,compile-only,print,debug:,ocode:,oexec:,verbose:,
  frama-c-only,extra-cpp-args:,frama-c-stdlib,full-mmodel,gmp,quiet,logfile:,
  ld-flags:,cpp-flags:,frama-c-extra:,memory-model:,production,no-stdlib,
  debug-log:,frama-c:,gcc:,e-acsl-share:,instrumented-only,rte:,oexec-e-acsl:,
  print-mmodels"
SHORTOPTIONS="h,c,C,p,d:,o:,O:,v:,f,E:,L,M,l:,e:,g,q,s:,F:,m:,P,N,D:,I:,G:,X,a:"
# Prefix for an error message due to wrong arguments
ERROR="ERROR parsing arguments:"

# Variables holding getopt options
OPTION_CFLAGS=                           # Compiler flags
OPTION_CPPFLAGS=                         # Preprocessor flags
OPTION_LDFLAGS=                          # Linker flags
OPTION_FRAMAC="frama-c"                  # Frama-C executable name
OPTION_CC="gcc"                          # GCC executable name
OPTION_ECHO="set -x"                     # Echo executed commands to STDOUT
OPTION_INSTRUMENT=1                      # Perform E-ACSL instrumentation
OPTION_PRINT=                            # Output instrumented code
OPTION_DEBUG=                            # Set Frama-C debug flag
OPTION_VERBOSE=                          # Set Frama-C verbose flag
OPTION_COMPILE=                          # Compile instrumented program
OPTION_OUTPUT_CODE="a.out.frama.c"       # Name of the translated file
OPTION_OUTPUT_EXEC="a.out"               # Generated executable name
OPTION_EACSL_OUTPUT_EXEC=""              # Name of E-ACSL executable
OPTION_EACSL="-e-acsl"                   # Specifies E-ACSL run
OPTION_FRAMA_STDLIB="-no-frama-c-stdlib" # Use Frama-C stdlib
OPTION_FULL_MMODEL=                      # Instrument as much as possible
OPTION_PRINT_MMODELS=                    # Print memory model names
OPTION_GMP=                              # Use GMP integers everywhere
OPTION_DEBUG_MACRO="-DE_ACSL_DEBUG"      # Debug macro
OPTION_DEBUG_LOG_MACRO=""                # Specification of debug log file
OPTION_FRAMAC_CPP_EXTRA=""               # Extra CPP flags for Frama-C
OPTION_EACSL_MMODELS="bittree"           # Memory model used
OPTION_EACSL_SHARE=                      # Custom E-ACSL share directory
OPTION_INSTRUMENTED_ONLY=                # Do not compile original code
OPTION_RTE=                              # Enable assertion generation
# The following option controls whether to use gcc builtins
# (e.g., __builtin_strlen) in RTL or fall back to custom implementations
# of standard functions.
OPTION_BUILTINS="-DE_ACSL_BUILTINS"

manpage() {
  printf "e-acsl-gcc.sh - instrument and compile C files with E-ACSL
Usage: e-acsl-gcc.sh [options] files
Options:
  -h         show this help page
  -c         compile instrumented code
  -l         pass additional options to the linker
  -e         pass additional options to the pre-preprocessor
  -E         pass additional arguments to the Frama-C pre-processor
  -p         output the generated code with rich formatting to STDOUT
  -o <file>  output the generated code to <file> [a.out.frama.c]
  -O <file>  output the generated executables to <file> [a.out, a.out.e-acsl]
  -M         maximize memory-related instrumentation
  -g         always use GMP integers instead of C integral types
  -q         suppress any output except for errors and warnings
  -s <file>  redirect all output to <file>
  -P         compile executable without debug features
  -I <file>  specify Frama-C executable [frama-c]
  -G <file>  specify C compiler executable [gcc]

Notes:
  This help page shows only basic options.
  See man (1) e-acsl-gcc.sh for full up-to-date documentation.\n"
  exit 1
}

# Base dir of this script
BASEDIR="$(readlink -f `dirname $0`)"
# Directory with contrib libraries of E-ACSL
LIBDIR="$BASEDIR/../lib"

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
    # Pass an option to a Frama-C invocation
    --frama-c-extra|-F)
      shift;
      FRAMAC_FLAGS="$FRAMAC_FLAGS $1"
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
      OPTION_OUTPUT_CODE="$1"
      shift
    ;;
    # Specify the base name of the executable generated from the
    # instrumented and non-instrumented sources.
    --oexec|-O)
      shift;
      OPTION_OUTPUT_EXEC="$1"
      shift
    ;;
    # Specify the output name of the E-ACSL generated executable
    --oexec-e-acsl)
      shift;
      OPTION_EACSL_OUTPUT_EXEC="$1"
      shift;
    ;;
    # Additional CPP arguments
    --extra-cpp-args|-E)
      shift;
      OPTION_FRAMAC_CPP_EXTRA="$OPTION_FRAMAC_CPP_EXTRA $1"
      shift;
    ;;
    # Additional flags passed to the linker
    --ld-flags|-l)
      shift;
      OPTION_LDFLAGS="$OPTION_LDFLAGS $1"
      shift;
    ;;
    # Additional flags passed to the pre-processor (compile-time)
    --cpp-flags|-e)
      shift;
      OPTION_CPPFLAGS="$OPTION_CPPFLAGS $1"
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
    # Run only Frama-C related instrumentation
    --frama-c-only|-f)
      shift;
      OPTION_EACSL=
    ;;
    # Do not compile original source file
    --instrumented-only|-X)
      shift;
      OPTION_INSTRUMENTED_ONLY=1
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
    -P|--production)
      shift;
      OPTION_DEBUG_MACRO=""
    ;;
    -N|--no-stdlib)
      shift;
      OPTION_BUILTINS=""
    ;;
    -D|--debug-log)
      shift;
      OPTION_DEBUG_LOG_MACRO="-DE_ACSL_DEBUG_LOG=$1"
      shift;
    ;;
    # Supply Frama-C executable name
    -I|--frama-c)
      shift;
      OPTION_FRAMAC="$(which $1)"
      shift;
    ;;
    # Supply GCC executable name
    -G|--gcc)
      shift;
      OPTION_CC="$(which $1)"
      shift;
    ;;
    # Specify EACSL_SHARE directory (where C runtime library lives) by hand
    # rather than compute it
    --e-acsl-share)
      shift;
      OPTION_EACSL_SHARE="$1"
      shift;
    ;;
    --rte|-a)
      shift;
      OPTION_RTE=`rte_options $1`
      error "Invalid argument $1 to --rte|-a option" $?
      shift;
    ;;
    # A memory model  (or models) to link against
    -m|--memory-model)
      shift;
      # Convert comma-separated string into white-space separated string
      OPTION_EACSL_MMODELS="`echo $1 | sed -s 's/,/ /g'`"
      shift;
    ;;
    # Print names of the supported memody models.
    --print-mmodels)
      shift;
      OPTION_PRINT_MMODELS="1"
    ;;
  esac
done
shift;

# Check Frama-C and GCC executable names
check_tool "$OPTION_FRAMAC"
check_tool "$OPTION_CC"

# Frama-C directories
FRAMAC="$OPTION_FRAMAC"
: ${FRAMAC_SHARE:="`$FRAMAC -print-share-path`"}
: ${FRAMAC_PLUGIN:="`$FRAMAC -print-plugin-path`"}

# Check if this is a development or an installed version
if [ -f "$BASEDIR/../E_ACSL.mli" ]; then
  # Development version
  DEVELOPMENT="$(readlink -f "$BASEDIR/..")"
  # Check if the project has been built, as if this is a non-installed
  # version that has not been built Frama-C will fallback to an installed one
  # for instrumentation but still use local RTL
  error "Plugin in $DEVELOPMENT not compiled" \
    `test -f "$DEVELOPMENT/META.frama-c-e_acsl" -o \
          -f "$FRAMAC_PLUGIN/META.frama-c-e_acsl"; echo $?`
  EACSL_SHARE="$DEVELOPMENT/share/e-acsl"
  # Add the project directory to FRAMAC_PLUGINS,
  # otherwise Frama-C uses an installed version
  if test -f "$DEVELOPMENT/META.frama-c-e_acsl"; then
      FRAMAC_FLAGS="-add-path=$DEVELOPMENT/top -add-path=$DEVELOPMENT $FRAMAC_FLAGS";
  fi
else
  # Installed version. FRAMAC_SHARE should not be used here as Frama-C
  # and E-ACSL may not be installed to the same location
  EACSL_SHARE="$BASEDIR/../share/frama-c/e-acsl/"
fi

# Architecture-dependent flags. Since by default Frama-C uses 32-bit
# architecture we need to make sure that same architecture is used for
# instrumentation and for compilation.
MACHDEPFLAGS="`getconf LONG_BIT`"
# Check if getconf gives out the value accepted by Frama-C/GCC
echo "$MACHDEPFLAGS" | grep '16\|32\|64' 2>&1 >/dev/null \
  || error "$MACHDEPFLAGS-bit architecture not supported"
# -machdep option sent to Frama-C
MACHDEP="-machdep gcc_x86_$MACHDEPFLAGS"
# Macro for correct preprocessing of Frama-C generated code
CPPMACHDEP="-D__FC_MACHDEP_X86_$MACHDEPFLAGS"
# GCC machine option
GCCMACHDEP="-m$MACHDEPFLAGS"

# Macro that identifies E-ACSL compilation. Passed to Frama-C
# and GCC runs but not to the original compilation
EACSL_MACRO_ID="__E_ACSL__"

# Frama-C and related flags
FRAMAC_CPP_EXTRA="$OPTION_FRAMAC_CPP_EXTRA \
  -I$FRAMAC_SHARE/libc \
  -D__NO_CTYPE \
  $CPPMACHDEP"
EACSL_MMODEL="$OPTION_EACSL_MMODEL"

# Re-set EACSL_SHARE  directory is it has been given by the user
if [ -n "$OPTION_EACSL_SHARE" ]; then
  EACSL_SHARE="$OPTION_EACSL_SHARE"
fi

# Check if the E-ACSL share directory is indeed an E-ACSL share directory that
# contains required C code. The check involves looking up
# $EACSL_SHARE/e_acsl_mmodel_api.h - one of the headers required by the Frama-C
# invocation. This is a week check but it is better than nothing.
error "Cannot find required $EACSL_SHARE/e_acsl_mmodel_api.h header" \
  `test -f "$EACSL_SHARE/e_acsl_mmodel_api.h"; echo $?`

# Echo the absolute path of the source file corresponding to a memory model
# given by the first argument, or report an error of the given model does not
# exist. In case no argument is supplied, output the names of the memory models
# supported in this distribution.
mmodel_sources() {
  local model="$1"
  local models=$(find $EACSL_SHARE -maxdepth 1 \
     -name '*_model'  -type d -exec basename {} \; | sed 's/_model$//')

  if [ -n "$model" ]; then
    model=$(echo $models | tr ' ' '\n' | grep "^$model$")
    if [ -n "$model" ]; then
      echo "$EACSL_SHARE/$model"_model/e_acsl_"$model"_mmodel.c
    else
      error "Memory model '$1' is not available in this distribution"
    fi
  else
    echo $models
  fi
}

# If specified, print the names of the supported memory models and exit
if [ -n "$OPTION_PRINT_MMODELS" ]; then
  mmodel_sources
  exit 0
fi

# Once EACSL_SHARE is defined check the memory models provided at inputs
for mod in $OPTION_EACSL_MMODELS; do
  mmodel_sources $mod > /dev/null
done

# Gcc and related flags
CC="$OPTION_CC"
CFLAGS="$OPTION_CFLAGS
  -std=c99 $GCCMACHDEP -g3 -fno-builtin -fno-merge-constants
  -Wall \
  -Wno-long-long \
  -Wno-attributes \
  -Wno-undef \
  -Wno-unused \
  -Wno-unused-function \
  -Wno-unused-result \
  -Wno-unused-value \
  -Wno-unused-function \
  -Wno-unused-variable \
  -Wno-unused-but-set-variable \
  -Wno-implicit-function-declaration \
  -Wno-empty-body"

if test -z "$OPTION_DEBUG_MACRO"; then
  CFLAGS="-O2 $CFLAGS"
else
  CFLAGS="-O0 $CFLAGS"
fi

# Disable extra warning for clang
if [ "`basename $CC`" = 'clang' ]; then
  CFLAGS="-Wno-unknown-warning-option \
    -Wno-extra-semi \
    -Wno-tautological-compare \
    -Wno-gnu-empty-struct \
    -Wno-incompatible-pointer-types-discards-qualifiers"
fi

CPPFLAGS="$OPTION_CPPFLAGS"
LDFLAGS="$OPTION_LDFLAGS"

# C, CPP and LD flags for compilation of E-ACSL-generated sources
EACSL_CFLAGS=""
EACSL_CPPFLAGS="
  -I$EACSL_SHARE
  -D$EACSL_MACRO_ID"
EACSL_LDFLAGS="-lm $LIBDIR/libgmp-e-acsl.a $LIBDIR/libjemalloc-e-acsl.a -lpthread"

# Output file names
OUTPUT_CODE="$OPTION_OUTPUT_CODE" # E-ACSL instrumented source
OUTPUT_EXEC="$OPTION_OUTPUT_EXEC" # Output name of the original executable
# Output name of E-ACSL-modified executable

if [ -z "$OPTION_EACSL_OUTPUT_EXEC" ]; then
    EACSL_OUTPUT_EXEC="$OPTION_OUTPUT_EXEC.e-acsl"
else
    EACSL_OUTPUT_EXEC="$OPTION_EACSL_OUTPUT_EXEC"
fi

# Build E-ACSL plugin argument string
if [ -n "$OPTION_EACSL" ]; then
  OPTION_EACSL="
    $OPTION_EACSL
    $OPTION_GMP
    $OPTION_FULL_MMODEL
    -then-last"
fi

# Bail if no files to translate are given
if [ -z "$1" ]; then
  error "no input files";
fi

# Instrument
if [ -n "$OPTION_INSTRUMENT" ]; then
  ($OPTION_ECHO; \
    $FRAMAC \
    $FRAMAC_FLAGS \
    $MACHDEP \
    -cpp-extra-args="$FRAMAC_CPP_EXTRA" \
    -e-acsl-share=$EACSL_SHARE \
    $OPTION_FRAMA_STDLIB \
    $OPTION_VERBOSE \
    $OPTION_DEBUG \
    "$@" \
    $OPTION_RTE \
    $OPTION_EACSL \
    -print -ocode "$OPTION_OUTPUT_CODE");
    error "aborted by Frama-C" $?;
  # Print translated code
  if [ -n "$OPTION_PRINT" ]; then
    cat $OPTION_OUTPUT_CODE
  fi
fi

# Compile
if [ -n "$OPTION_COMPILE" ]; then
  # Compile original source code
  # $OPTION_INSTRUMENT is set -- both, instrumented and original, sources are
  # available. Do compile the original program unless instructed to not do so
  # by a user
  if [ -n "$OPTION_INSTRUMENT" ]; then
    if [ -z "$OPTION_INSTRUMENTED_ONLY" ]; then
      ($OPTION_ECHO; $CC $CPPFLAGS $CFLAGS "$@" -o "$OUTPUT_EXEC" $LDFLAGS);
      error "fail to compile/link un-instrumented code" $?;
    fi
  # If $OPTION_INSTRUMENT is unset then the sources are assumed to be already
  # instrumented, so skip compilation of the original files
  else
    OUTPUT_CODE="$@"
  fi

  # Compile and link E-ACSL-instrumented file with all models specified
  for mod in $OPTION_EACSL_MMODELS; do
    # If multiple models are specified then the generated executable
    # is appended a '-MODEL' suffix, where MODEL is the name of the memory
    # model used
    if ! [ "`echo $OPTION_EACSL_MMODELS | wc -w`" = 1 ]; then
      OUTPUT_EXEC="$EACSL_OUTPUT_EXEC-$mod"
    else
      OUTPUT_EXEC="$EACSL_OUTPUT_EXEC"
    fi
    # Sources of the selected memory model
    EACSL_RTL=`mmodel_sources "$mod"`
    ($OPTION_ECHO;
     $CC \
       $CFLAGS $CPPFLAGS \
       $EACSL_CFLAGS $EACSL_CPPFLAGS \
       $EACSL_RTL \
       $OPTION_DEBUG_MACRO \
       $OPTION_DEBUG_LOG_MACRO \
       $OPTION_BUILTINS \
       -o "$OUTPUT_EXEC" \
       "$OUTPUT_CODE" \
       $LDFLAGS $EACSL_LDFLAGS)
    error "fail to compile/link instrumented code" $?
  done
fi
exit 0;
