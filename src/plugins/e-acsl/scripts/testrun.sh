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

# Convenience script for running tests with E-ACSL. Given a source file the
# sequence is as follows:
#   1. Perform E-ACSL instrumentation
#   2. Compile instrumented and original files
#   3. Compare outputs of the above

# Arguments:
#   $1 - base name of the source file to use excluding an
#     extension (e.g., addrOf)
#   $2 - base name of the test suite directory the test file is located in.
#     (for instance e-acsl-runtime). Provided that ROOT is the directory
#     holding the E-ACSL repository there should be either:
#     $ROOT/test/e-acsl-runtime/addrOf.i or
#     $ROOT/test/e-acsl-runtime/addrOf.c
#   $3 - if specified this script re-runs test sequence generating using
#       -e-acsl-gmp-only option
#   $4 - debug flag

set -e

TEST="$1" # Based name of the test file with extension stripped
PREFIX="$2" # Prefix (test suite) directory, e.g., bts, e-acsl-runtime
GMP="$3" # Whether to use a subsequent run with -e-acsl-gmp-only
DEBUG="$4" # Debug flag

ROOTDIR="`readlink -f $(dirname $0)/../`" # Root directory of the repository
TESTDIR="$ROOTDIR/tests/$PREFIX"
RESDIR=$TESTDIR/result # result directory within the test suite
TESTFILE=`ls $TESTDIR/$TEST.[ic]` # Source test file
MODEL="bittree" # Memory model to link against.

LOG="$RESDIR/$TEST.testrun" # Base name for log files
OUT="$RESDIR/gen_$TEST"     # Base name for output
RUNS=1

# Error reporting
error() {
  echo "Error: $1" 1>&2
  echo "See $2 for details" 1>&2
  exit 1
}

# Clean up log/output files unless the DEBUG flag is set
clean() {
    if [ -z "$DEBUG" ]; then
        rm -f $LOG.* $OUT.*
    fi
}

 # Do clean up on exit
trap "clean" EXIT HUP INT QUIT TERM

# Instrument the given test using e-acsl-gcc.sh and compare outputs of the
# executables generated from instrumented and non-instrumented sources
run_test() {
  local ocode=$OUT.$RUNS.c # Generated source file
  local logfile=$LOG.$RUNS.elog # Log file for e-acsl-gcc.sh output
  local oexec=$OUT.$RUNS.out # Generated executable name
  local oexeclog=$LOG.$RUNS.rlog # Log for executable output
  local extra="$1" # Additional arguments to e-acsl-gcc.sh

  # Command for instrumenting the source file and compiling the original
  # and the instrumented code
  EACSL_GCC="e-acsl-gcc.sh
    --compile $TESTFILE --ocode=$ocode --logfile=$logfile
    --memory-model=$MODEL --oexec=$oexec $extra"

  $EACSL_GCC || error "Command $EACSL_GCC failed" "$logfile"

  # Log outputs of the generated executables
  $oexec         2>&1 > $oexeclog.native
  $oexec.e-acsl  2>&1 > $oexeclog.e-acsl

  ## Make sure that instrumented and uninstrumented programs have same outputs
  diff $oexeclog.native $oexeclog.e-acsl ||
    error "Output of programs before and after instrumentation differ" \
      "output of $oexec and $oexec.e-acsl"

  RUNS=$((RUNS+1))
}

run_test
if test -n "$GMP"; then
  run_test "--gmp"
fi
exit 0
