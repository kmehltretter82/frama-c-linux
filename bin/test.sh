#!/bin/bash
##########################################################################
#                                                                        #
#  This file is part of Frama-C.                                         #
#                                                                        #
#  Copyright (C) 2007-2023                                               #
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
CLEAN=
PREPARE=
PULLCACHE=
UPDATE=
LOGS=
COMMIT=
TESTS=
SAVE=
COVER=

DUNE_ALIAS=
DUNE_OPT=
DUNE_LOG=./.test-errors.log
ALIAS_NAME=ptests
LOCAL_WP_CACHE=$(pwd -P)/.wp-cache
FRAMAC_WP_CACHE_GIT=git@git.frama-c.com:frama-c/wp-cache.git

TEST_DIRS="tests/* src/plugins/*/tests/* src/kernel_internals/parsing/tests"

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
    echo "  -a|--all            run all tests (default behavior)"
    echo "  -d|--default        run tests from default config only"
    echo "  -c|--config <name>  run tests from specified config only"
    echo ""
    echo ""
    echo "OPTIONS"
    echo ""
    echo "  -n|--name <alias>   set dune alias name (default to ptests)"
    echo "  -r|--clean          clean (remove all) test results (includes -p)"
    echo "  -p|--ptests         prepare (all) dune files"
    echo "  -w|--wp-cache       prepare (pull) WP-cache"
    echo "  -l|--logs           print output of tests (single file, no diff)"
    echo "  -u|--update         run tests and update oracles (and WP-cache)"
    echo "  -k|--commit         commit new test oracles"
    echo "  -s|--save           save dune logs into $DUNE_LOG"
    echo "  -v|--verbose        print executed commands"
    echo "  -j|--jobs <jobs>    run no more than <jobs> commands simultaneously."
    echo "  --coverage          compute test coverage"
    echo "  -h|--help           print this help"
    echo ""
    echo "VARIABLES"
    echo ""
    echo "  FRAMAC_WP_CACHE"
    echo "    Management mode of wp-cache (default is offline or update when -u)"
    echo ""
    echo "  FRAMAC_WP_QUALIF"
    echo "  FRAMAC_WP_CACHEDIR"
    echo "    Absolute path to wp-cache directory (git clone locally by default)"
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

function RequiredTools
{
    for tool in $@ ; do
        Where=$(which $tool) || Error "Executable not found: $tool"
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
            CLEAN=yes
            PREPARE=yes
            ;;
        "-p"|"--ptests")
            PREPARE=yes
            ;;
        "-w"|"--wp-cache")
            PULLCACHE=yes
            ;;
        "-u"|"--update")
            DUNE_OPT+="--auto-promote "
            UPDATE=yes
            ;;
        "-v"|"--verbose")
            DUNE_OPT+="--display=short "
            VERBOSE=yes
            ;;
        "-j"|"--jobs")
            if [[ $2 == "auto" ]] || ([[ $2 != \-* ]] && [[ $2 -ge 1 ]]); then
                DUNE_OPT+="-j $2 "
                shift
            else
                ErrorUsage \
                    "wrong opt ('$2') for '-j|--jobs', value 'auto' or >= 1 expected"
            fi
            ;;
        "-l"|"--logs")
            LOGS=yes
            ;;
        "-k"|"--commit")
            COMMIT=yes
            ;;
        "-s"|"--save" )
            SAVE=yes
            ;;
        "-d"|"--default")
            CONFIG="<default>"
            ;;
        "-c"|"--config")
            CONFIG=$2
            shift
            ;;
        "--coverage")
            COVER=yes
            DUNE_OPT+="--workspace dev/dune-workspace.cover "
            ;;
        "-n"|"--name")
            ALIAS_NAME=$2
            shift
            ;;
        "-a"|"--all")
            TESTS=""
            for dir in $TEST_DIRS ; do
                if [ -d "$dir" ]; then
                    TESTS="$TESTS $dir"
                fi
            done
            ;;
       *)
            TESTS+=" $1"
            ;;
    esac
    shift
done

# --------------------------------------------------------------------------
# ---  WP Cache Environment
# --------------------------------------------------------------------------

function SetEnv
{
    if [ "$FRAMAC_WP_CACHE" = "" ]; then
        if [ "$UPDATE" = "yes" ]; then
            Head "FRAMAC_WP_CACHE=update"
            export FRAMAC_WP_CACHE=update
        else
            export FRAMAC_WP_CACHE=offline
        fi
    else
        if [ "$UPDATE" = "yes" ]; then
            Head "FRAMAC_WP_CACHE=$FRAMAC_WP_CACHE (overrides -u)"
        else
            Head "FRAMAC_WP_CACHE=$FRAMAC_WP_CACHE"
        fi
    fi

    if [ "$FRAMAC_WP_QUALIF" != "" ]; then
        export FRAMAC_WP_CACHEDIR="$FRAMAC_WP_QUALIF"
        Echo "# FRAMAC_WP_CACHEDIR=$FRAMAC_WP_CACHEDIR"
    elif [ "$FRAMAC_WP_CACHEDIR" = "" ]; then
        export FRAMAC_WP_CACHEDIR="$LOCAL_WP_CACHE"
        Echo "# FRAMAC_WP_CACHEDIR=$FRAMAC_WP_CACHEDIR"
    fi

    [ ! -f "$FRAMAC_WP_CACHEDIR" ] || [ -d "$FRAMAC_WP_CACHEDIR" ] \
        || Error "$FRAMAC_WP_CACHEDIR is not a directory"

    case "$FRAMAC_WP_CACHEDIR" in
        /*);;
        *) Error "Requires an absolute path to $FRAMAC_WP_CACHEDIR";;
    esac
}

function CloneCache
{
    if [ ! -d "$FRAMAC_WP_CACHEDIR" ]; then
        Head "Cloning WP cache (from $FRAMAC_WP_CACHE_GIT to $FRAMAC_WP_CACHEDIR)..."
        RequiredTools git
        Cmd git clone $FRAMAC_WP_CACHE_GIT $FRAMAC_WP_CACHEDIR
    fi
}

function PullCache
{
    if [ "$PULLCACHE" = "yes" ]
    then
        CloneCache
        Head "Pull WP cache (to $FRAMAC_WP_CACHEDIR)..."
        RequiredTools git
        Run git -C $FRAMAC_WP_CACHEDIR pull --rebase
    fi
}

# --------------------------------------------------------------------------
# ---  Coverage
# --------------------------------------------------------------------------

function PrepareCoverage
{
    export BISECT_FILE="$(pwd -P)/_bisect/bisect-"
    if [ "$COVER" = "yes" ] ;
    then
        Cmd rm -rf _coverage
        Cmd rm -rf _bisect
        Cmd mkdir _bisect
    fi
}

function GenerateCoverage
{
    if [ "$COVER" = "yes" ] ;
    then
        Head "Generating coverage in _coverage ..."
        Cmd bisect-ppx-report html --coverage-path=_bisect
    fi
}

# --------------------------------------------------------------------------
# ---  Test Suite Preparation
# --------------------------------------------------------------------------

function PrepareTests
{
    if [ "$CLEAN" = "yes" ]
    then
        Head "Cleaning all tests..."
        Cmd make clean-tests
    fi
    if [ "$PREPARE" = "yes" ]
    then
        Head "Generating dune files..."
        Cmd make run-ptests
    fi
}

# --------------------------------------------------------------------------
# ---  Test Dir Alias
# --------------------------------------------------------------------------

[ "$DUNE_LOG" = "" ] || rm -rf $DUNE_LOG
function RunAlias
{

    Head "Running tests..."
    if [ "$DUNE_LOG" = "" ]; then
        Run dune build $DUNE_OPT $@
    elif [ "$SAVE" != "yes" ] && [ "$VERBOSE" != "yes" ]; then
        Run dune build $DUNE_OPT $@
    else
        # note: the Run function cannot performs redirection
        echo "> dune build $DUNE_OPT $@ 2> >(tee -a $DUNE_LOG >&2)"
        dune build $DUNE_OPT $@ 2> >(tee -a $DUNE_LOG >&2)
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
            ALIAS=$1/${ALIAS_NAME}
            CFG="(all configs)"
            ;;
        "<default>")
            ALIAS=$1/${ALIAS_NAME}_config
            CFG="(default config)"
            ;;
        *)
            ALIAS=$1/${ALIAS_NAME}_config_$CONFIG
            CFG="(config $CONFIG)"
            ;;
    esac
    Head "Register test on directory $1 $CFG"
    DUNE_ALIAS="${DUNE_ALIAS} @$ALIAS"
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
        ALIAS=$DIR/$RESULT/${FILE%.*}.diff
    fi
    if [ "$COMMIT" = "yes" ]; then
        COMMITS="${COMMITS} $DIR/$RESULT/${FILE%.*}"
    fi
    Head "Register test on file $1 $CFG"
    DUNE_ALIAS="${DUNE_ALIAS} @$ALIAS"
}

# --------------------------------------------------------------------------
# ---  Tests Processing
# --------------------------------------------------------------------------

function Register
{
    while [ "$1" != "" ]
    do
        if [ -d $1 ]; then
            TestDir $1
        elif [ -f $1 ]; then
            TestFile $1
        else
            case $1 in
                @*) Head "Register test on alias $1"; DUNE_ALIAS="${DUNE_ALIAS} $1";;
                *) ErrorUsage "ERROR: don't known what to do with '$1'";;
            esac
        fi
        shift
    done
}

# --------------------------------------------------------------------------
# ---  Tests Commits
# --------------------------------------------------------------------------

function Commits
{
    while [ "$1" != "" ]
    do
        cd _build/default
        for log in $1*.res.log
        do
            echo "Commit $log"
            dest="${log//result/oracle}"
            dest="${dest//res.log/res.oracle}"
            cp -f $log "../../$dest"
        done
        cd ../..
        shift
    done
}

# --------------------------------------------------------------------------
# ---  Tests Numbering
# --------------------------------------------------------------------------

function Status
{
    #-- Count number of executed tests
    if [ "$1" != "" ] && [ -f "$1" ]; then
        if [ "$VERBOSE" = "yes" ] ; then
            #-- Total
            NB=$(grep -c "^frama-c-wtests " "$1")
            Head "Number of executed frama-c-wtests= $NB"
            #-- Details
            Head "Details by directory:"
            if  [ "$NB" != "0" ]; then
                for dir in $TEST_DIRS ; do
                    if [ -d "$dir" ]; then
                        NB=$(grep -c "^frama-c-wtests $dir" "$1")
                        [ "$NB" = "0" ] || echo "- $dir= $NB"
                    fi
                done
            fi
        fi
        if [ "$SAVE" != "yes" ]; then
            Cmd rm -f $1
        fi
    fi

    #-- Check wp-cache status
    if [ "$UPDATE" = "yes" ]; then
        Head "Update $FRAMAC_WP_CACHEDIR and check status"
        RequiredTools git
        Run git -C $FRAMAC_WP_CACHEDIR add -A
        Run git -C $FRAMAC_WP_CACHEDIR status -s
    fi
}

# --------------------------------------------------------------------------
# ---  Main Program
# --------------------------------------------------------------------------

SetEnv
PullCache
PrepareCoverage
PrepareTests
Register $TESTS
RunAlias ${DUNE_ALIAS}
Commits ${COMMITS}
Status $DUNE_LOG
GenerateCoverage

# --------------------------------------------------------------------------
