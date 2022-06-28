#!/bin/bash
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
COUNT=

FRAMAC_WP_CACHE_GIT=git@git.frama-c.com:frama-c/wp-cache.git

# --------------------------------------------------------------------------
# ---  Help Message
# --------------------------------------------------------------------------

THIS_SCRIPT="$0"
function Usage
{
    echo "USAGE"
    echo ""
    echo "${THIS_SCRIPT} [OPTIONS|TESTS]..."
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
    echo "  -r|--clean          clean (remove all) test results (includes -p)"
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
    echo "  FRAMAC_WP_CACHEDIR=$FRAMAC_WP_CACHEDIR"
    echo "    Git URL: $FRAMAC_WP_CACHE_GIT"
    echo "    Please, always push updates to #master branch"
    echo ""
    echo "  FRAMAC_WP_CACHE=$FRAMAC_WP_CACHE"
    echo "    Management mode of wp-cache"
    echo ""
}

# --------------------------------------------------------------------------
# ---  Utilities
# --------------------------------------------------------------------------

function Head()
{
    echo "# $@"
}

function Error ()
{
    echo "Error: $@"
    exit 1
}

function ErrorUsage ()
{
    echo "Error: $@"
    echo "USAGE: ${THIS_SCRIPT} -h"
    exit 1
}

function Echo()
{
    [ "$VERBOSE" != "yes" ] || echo $@
}

function Run
{
    Echo "> $@"
    $@
}

function Cmd
{
    Run $@
    [ "$?" = "0" ] || Error "(command exits $?): $@"
}

# --------------------------------------------------------------------------
# ---  WP Cache Environment
# --------------------------------------------------------------------------

function CloneCache
{
    if [ ! -d "$FRAMAC_WP_CACHEDIR" ]; then
        Head "Cloning WP cache..."
        Cmd git clone $FRAMAC_WP_CACHE_GIT $FRAMAC_WP_CACHEDIR
    fi
}

function PullCache
{
    Head "Pull WP cache..."
    Run git -C $FRAMAC_WP_CACHEDIR pull --rebase
}

function SetEnv
{
    if [ "$FRAMAC_WP_CACHE" = "" ]
    then
        FRAMAC_WP_CACHE=offline
        Echo "Set FRAMAC_WP_CACHE=$FRAMAC_WP_CACHE"
    fi

    if [ "$FRAMAC_WP_CACHEDIR" = "" ]
    then
        FRAMAC_WP_CACHEDIR=.wp-cache
        Echo "Set FRAMAC_WP_CACHEDIR=$FRAMAC_WP_CACHEDIR"
    fi

    CloneCache
    PullCache

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
    Head "Running test on directory $1"
    Run dune build @$ALIAS
}

# --------------------------------------------------------------------------
# ---  Test File Processing
# --------------------------------------------------------------------------

function TestFile
{
    DIR=$(dirname $1)
    FILE=$(basename $1)
    [ "$CONFIG" != "<all>" ] || \
        echo "Warning: can not run single test in all config"

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
    Head "Running test on file $1"
    Cmd build @$ALIAS
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
            ErrorUsage "ERROR: don't known what to do with '$1'"
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
            Head "Cleaning all tests..."
            Cmd make clean-tests
            Head "Generating dune files..."
            Cmd make run-ptests
            ;;
        "-p"|"--ptests")
            Head "Generating dune files..."
            Cmd make run-ptests
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
        "-a"|"--all")
            TESTS="tests src/plugins/*/tests"
            ;;
        "-n"|"--count")
            COUNT=yes
            ;;
       *)
            TESTS+=" $1"
            ;;
    esac
    shift
done

SetEnv
RunTests $TESTS

#-- Count number of .res.log files
if [ "$COUNT" = "yes" ]; then

    BUILD=_build/default

    Head "Number of .res.log files by test directory..."
    NB=
    for dir in tests src/plugins/*/tests ; do
        if [ ! -d "$dir" ] ; then
            NB="$((find $BUILD/$dir -name \*.res.log 2> /dev/null) | wc -l)"
            [ "$NB" = "0"] || echo "- $dir= $NB"
        fi
    done
    [ "$NB" != "" ] || echo "- <none>"

fi
