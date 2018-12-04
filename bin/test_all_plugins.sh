#!/bin/bash
##########################################################################
#                                                                        #
#  This file is part of Frama-C.                                         #
#                                                                        #
#  Copyright (C) 2007-2018                                               #
#    CEA (Commissariat à l'énergie atomique et aux énergies              #
#         alternatives)                                                  #
#                                                                        #
#  All rights reserved.                                                  #
#  Contact CEA LIST for licensing.                                       #
#                                                                        #
##########################################################################


# This script must be executed from the trunk

# Executing this script requires bash 4.0 or higher
# (special use of the 'case' construct)
if test `echo $BASH_VERSION | sed "s/\([0-9]\).*/\1/" ` -lt 4; then
  echo "bash version >= 4 is required."
  exit 99
fi

# Set it to "no" in order to really execute the commands.
# Otherwise, they are only printed.
DEBUG=no

echo -n "Steps are:
  1) Updating and cleaning plug-ins
  2) Compiling plug-ins
  3) Testing plug-ins
Which step? (default is 1) "
read STEP

PLUGIN_DIR=../plugins
WHY_DIR=why

PLUGIN_LIST="$PLUGIN_DIR/a3export \
    $PLUGIN_DIR/caveat2fc \
    $PLUGIN_DIR/mthread \
    $PLUGIN_DIR/security \
    $WHY_DIR/frama-c-plugin"

#    $PLUGIN_DIR/jcard \
#    $PLUGIN_DIR/misra/trunk \

step () {
  echo
  echo $1
}

run () {
  for dir in $PLUGIN_LIST; do
    cmd="(cd $dir; $1)"
    echo "$cmd"
    if test "$DEBUG" == "no"; then
      eval "$cmd" || { echo "Aborting at step $STEP."; exit $STEP; }
    fi
  done
}

case $STEP in
  ""|1)
    step "Step 1: UPDATING AND CLEANING PLUG-INS"
    run "svn up && if test -f configure.in -o -f configure.ac; then autoconf && ./configure; fi && make clean && make depend"
    ;&
  2)
    step "Step 2: COMPILING PLUG-INS"
    run "make"
    ;&
  3)
    step "Step 3: TESTING PLUG-INS"
    run "make tests"
    ;;
  4)
    echo "Bad entry: $STEP"
    echo "Exiting without doing anything.";
    exit 4
    ;;
esac

exit 0


