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

THIS_SCRIPT="$0"
CONFIG="<all>"
VERBOSE=
UPDATE=
LOGS=
TESTS=

VERBOSE_LOG=.test-errors.log

FRAMAC_WP_CACHE_GIT=git@git.frama-c.com:frama-c/wp-cache.git

# --------------------------------------------------------------------------
# ---  Help Message
# --------------------------------------------------------------------------

function Usage
{
    echo "USAGE"
    echo ""
    echo "${THIS_SCRIPT} [OPTIONS|TESTS]..."
    echo ""
    echo "TESTS SPECIFICATION"
    echo ""
    echo "  Tip: use shell completion"
    echo ""
    echo "  <DIR>     all tests in <DIR>"
    echo "  <FILE>    single test file <FILE>"
    echo ""
    echo "  -a|--all            run all tests"
    echo "  -d|--default        run tests from default config only"
    echo "  -c|--config <name>  run tests from specified config only"
    echo ""
    echo ""
    echo "OPTIONS"
    echo ""
    echo "  -r|--clean          clean (remove all) test results (includes -p)"
    echo "  -p|--ptests         prepare (all) dune files and pull cache"
    echo "  -l|--logs           print output of tests (single file, no diff)"
    echo "  -u|--update         run tests and update wp-cache"
    echo "  -v|--verbose        print executed commands"
    echo "  -h|--help           print this help"
    echo ""
    echo "VARIABLES"
    echo ""
    echo "  FRAMAC_WP_CACHE ($FRAMAC_WP_CACHE)"
    echo "    Management mode of wp-cache"
    echo ""
    echo "  FRAMAC_WP_CACHEDIR ($FRAMAC_WP_CACHEDIR)"
    echo "    Use $FRAMAC_WP_CACHE_GIT"
    echo "    Please, always push to master branch"
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

function SetEnv
{
    if [ "$FRAMAC_WP_CACHE" = "" ]; then
        FRAMAC_WP_CACHE=offline
        Echo "Set FRAMAC_WP_CACHE=$FRAMAC_WP_CACHE"
    fi

    if [ "$FRAMAC_WP_CACHEDIR" = "" ]; then
        FRAMAC_WP_CACHEDIR=./.wp-cache
        Echo "Set FRAMAC_WP_CACHEDIR=$FRAMAC_WP_CACHEDIR"
    fi

}

function CloneCache
{
    if [ ! -d "$FRAMAC_WP_CACHEDIR" ]; then
        Head "Cloning WP cache (from $FRAMAC_WP_CACHE_GIT to $FRAMAC_WP_CACHEDIR)..."
        Cmd git clone $FRAMAC_WP_CACHE_GIT $FRAMAC_WP_CACHEDIR
    fi
}

function PullCache
{
    CloneCache
    Head "Pull WP cache (to $FRAMAC_WP_CACHEDIR)..."
    Run git -C $FRAMAC_WP_CACHEDIR pull --rebase
}

# --------------------------------------------------------------------------
# ---  Test Dir Alias
# --------------------------------------------------------------------------

rm -rf $VERBOSE_LOG
function TestAlias
{

    if [ "$VERBOSE" != "yes" ]; then
        Run dune build $@
    elif [ "$VERBOSE_LOG" = "" ]; then
        Run build --display short
    else
        # note: the Run function cannot performs redirection
        echo "> build --display short $@ 2> >(tee -a $VERBOSE_LOG >&2)"
        dune build --display short $@ 2> >(tee -a $VERBOSE_LOG >&2)
    fi
}

# --------------------------------------------------------------------------
# ---  Test Dir Processing
# --------------------------------------------------------------------------

function TestDir
{
    CloneCache
    case "$CONFIG" in
        "<all>")
            ALIAS=$1/ptests
            CFG="(all configs)"
            ;;
        "<default>")
            ALIAS=$1/ptests_config
            CFG="(default config)"
            ;;
        *)
            ALIAS=$1/ptests_config_$CONFIG
            CFG="(config $CONFIG)"
            ;;
    esac
    Head "Running test on directory $1 $CFG"
    TestAlias @$ALIAS
}

# --------------------------------------------------------------------------
# ---  Test File Processing
# --------------------------------------------------------------------------

function TestFile
{
    CloneCache
    DIR=$(dirname $1)
    FILE=$(basename $1)

    case "$CONFIG" in
        "<all>"|"<default>")
            RESULT=result
            CFG="(default config)"
            ;;
        *)
            RESULT=result_$CONFIG
            CFG="(config $CONFIG)"
            ;;
    esac
    if [ "$LOGS" = "yes" ]; then
        ALIAS=$DIR/$RESULT/$FILE
    else
        ALIAS=$DIR/$RESULT/${FILE%.*}.wtests
    fi
    Head "Running test on file $1 $CFG"
    TestAlias @$ALIAS
}

# --------------------------------------------------------------------------
# ---  Tests Processing
# --------------------------------------------------------------------------

function RunTests
{
    while [ "$1" != "" ]
    do
        if [ -d $1 ]; then
            TestDir $1
        elif [ -f $1 ]; then
            TestFile $1
        else
            case $1 in
                @*) Head "Running test on alias $1"; TestAlias $1;;
                *) ErrorUsage "ERROR: don't known what to do with '$1'";;
            esac
        fi
        shift
    done
}


# --------------------------------------------------------------------------
# ---  Tests Numbering
# --------------------------------------------------------------------------

function CountTests
{
    #-- Count number of .res.log files
    if [ "$VERBOSE" = "yes" ]; then

        if [ -f "$VERBOSE_LOG" ]; then
            echo "# Number of executed frama-c-wtests= $(grep -c "^frama-c-wtests " $VERBOSE_LOG)"
            Cmd rm -f $VERBOSE_LOG
        fi

        BUILD=_build/default

        Head "Number of *.{err,res}.log files by test directory..."
        NB=
        for dir in tests src/plugins/*/tests ; do
            if [ -d "$dir" ]; then
                NB="$((find $BUILD/$dir -name \*.err.log -or -name \*.res.log 2> /dev/null) | wc -l)"
                [ "$NB" = "0" ] || echo "- $dir= $NB"
            fi
        done
        [ "$NB" != "" ] || echo "- <none>"

    fi

    #-- Check wp-cache status
    if [ "$UPDATE" = "yes" ]; then
        Head "Check $FRAMAC_WP_CACHEDIR status"
        git -C $FRAMAC_WP_CACHEDIR status -s
    fi
}

# --------------------------------------------------------------------------
# ---  Command Line Processing
# --------------------------------------------------------------------------

SetEnv
while [ "$1" != "" ]
do
    case "$1" in
        "-h"|"-help"|"--help")
            Usage
            exit 0
            ;;
        "-r"|"--clean")
            PullCache
            Head "Cleaning all tests..."
            Cmd make clean-tests
            Head "Generating dune files..."
            Cmd make run-ptests
            ;;
        "-p"|"--ptests")
            PullCache
            Head "Generating dune files..."
            Cmd make run-ptests
            ;;
        "-u"|"--update")
            FRAMAC_WP_CACHE=update
            UPDATE=yes
            ;;
        "-v"|"--verbose")
            VERBOSE=yes
            ;;
        "-l"|"--logs")
            LOGS=yes
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
       *)
            TESTS+=" $1"
            ;;
    esac
    shift
done
RunTests $TESTS
CountTests
