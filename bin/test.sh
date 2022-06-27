#!/bin/sh
##########################################################################
#                                                                        #
#  This file is part of Frama-C.                                         #
#                                                                        #
#  Copyright (C) 2007-2022                                               #
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
#  for more details (enclosed in the file licenses/LGPLv2.1).            #
#                                                                        #
##########################################################################

CONFIG="<all>"
UPDATE=
VERBOSE=
TESTS=

if [ ! -d "$FRAMAC_WP_QUALIF" ]
then
    echo "Warning: FRAMAC_WP_QUALIF not set"
    FRAMAC_WP_CACHE=replay
else
    FRAMAC_WP_CACHE=offline
    FRAMAC_WP_CACHEDIR=$FRAMAC_WP_QUALIF
fi

# --------------------------------------------------------------------------
# ---  Help Message
# --------------------------------------------------------------------------

function Usage
{
    echo "USAGE"
    echo ""
    echo "./bin/test.sh [OPTIONS|TESTS]..."
    echo ""
    echo "TESTS SPECIFICATION"
    echo ""
    echo "  If no test is specified, run all tests in all config."
    echo "  Tip: use shell completion"
    echo ""
    echo "  <DIR>     all tests in directory"
    echo "  <FILE>    single test file"
    echo ""
    echo "OPTIONS"
    echo ""
    echo "  -r|--clean          clean (remove all) test results"
    echo "  -p|--ptests         prepare (all) dune files"
    echo "  -v|--verbose        display (next) tests output"
    echo "  -u|--update         run tests and update wp-cache"
    echo "  -d|--default        run tests from default config only"
    echo "  -c|--config <name>  run tests from specified config only"
    echo ""
    echo "  -h|--help           print this help"
    echo ""
    echo "VARIABLES"
    echo ""
    echo "  FRAMAC_WP_QUALIF"
    echo "  Clone of git@git.frama-c.com:frama-c/wp-cache.git"
    echo "  Please, always push updates to #master branch"
    echo ""
}

# --------------------------------------------------------------------------
# ---  Test Dir Processing
# --------------------------------------------------------------------------

function TestDir
{
    case "$CONFIG" in
        "<all>")
            ALIAS=$1/ptests
            ;;
        "<default>")
            ALIAS=$1/ptests_config
            ;;
        *)
            ALIAS=$1/ptests_config_$CONFIG
            ;;
    esac
    echo "dune build @$ALIAS"
    dune build @$ALIAS
    if [ $? != 0 ]
    then
        exit $?
    fi
}

# --------------------------------------------------------------------------
# ---  Test File Processing
# --------------------------------------------------------------------------

function TestFile
{
    DIR=$(dirname $1)
    FILE=$(basename $1)
    if [ "$CONFIG" == "<all>" ]
    then
        echo "Warning: can not run single test in all config"
    fi
    case "$CONFIG" in
        "<all>"|"<default>")
            RESULT=result
            ;;
        *)
            RESULT=result_$CONFIG
            ;;
    esac
    if [ "$VERBOSE" == "yes" ]
    then
        ALIAS=$DIR/$RESULT/$FILE
    else
        ALIAS=$DIR/$RESULT/${FILE%.*}.wtests
    fi
    echo "dune build @$ALIAS"
    dune build @$ALIAS
    if [ $? != 0 ]
    then
        exit $?
    fi
}

# --------------------------------------------------------------------------
# ---  Tests Processing
# --------------------------------------------------------------------------

function RunTests
{
    while [ "$1" != "" ]
    do
        if [ -d $1 ]
        then
            TestDir $1
        elif [ -f $1 ]
        then
            TestFile $1
        else
            echo "ERROR: don't known what to do with '$1'"
            echo "USAGE: bin/test.sh -h"
            exit 1
        fi
        shift
    done
}

# --------------------------------------------------------------------------
# ---  Command Line Processing
# --------------------------------------------------------------------------

while [ "$1" != "" ]
do
    case "$1" in
        "-h"|"-help"|"--help")
            Usage
            exit 0
            ;;
        "-r"|"--clean")
            echo "Cleaning all tests"
            make clean-tests
            ;;
        "-p"|"--ptests")
            make run-ptests
            ;;
        "-u"|"--update")
            UPDATE=yes
            FRAMAC_WP_CACHE=update
            ;;
        "-v"|"--verbose")
            VERBOSE=yes
            ;;
        "-d"|"--default")
            CONFIG="<default>"
            ;;
        "-c"|"--config")
            CONFIG=$2
            shift
            ;;
        *)
            TESTS+=" $1"
            ;;
    esac
    shift
done

RunTests $TESTS
