#!/usr/bin/env bash

# Perform some checks on the output of the Metrics plugin, but avoiding
# too many details which cause conflicts during merge of libc branches.
# This test reads stdin and expects to find the output of 2 metrics runs:
# the first one with -metrics-libc and the second one with -metrics-no-libc.
# It then greps some lines and numbers, and check that their values are
# within specific conditions

echo "Checking libc metrics..."

regex=" *([a-zA-Z0-9\' -]+)+ +\(([0-9]+)\)"

# tbl: stores mappings (<run>-<title>, <count>), where <run> is the
# metrics run (1 or 2), <title> is the Metrics title for the category,
# and <count> is the number between parentheses reported by Metrics.
declare -A tbl

check () { # $1: state, $2: title, $3: expected cond
    key="$1-$2"
    count=${tbl[$key]}
    test_exp='! [ $count $3 ]'
    if eval $test_exp; then
        echo "warning: [metrics run $state]: $2: expected $3, got $count"
    fi
}

# read stdin line by line and store relevant ones
# uses the '[metrics]' prefix to detect when a new run starts
state=0
while IFS= read -r line; do
    if [[ $line =~ "[metrics]" ]]; then
        state=$((state + 1))
    fi
    if [[ $line =~ $regex ]]; then
        title="${BASH_REMATCH[1]}"
        count=${BASH_REMATCH[2]}
        tbl["$state-$title"]=$count
        key="$state-$title"
    fi
done

# conditions to be checked

check 1 "Defined functions" "> 100"
check 1 "Specified-only functions" "> 400"
check 1 "Undefined and unspecified functions" "< 2"
check 1 "'Extern' global variables" "> 20"
check 1 "Potential entry points" "= 1"

check 2 "Defined functions" "= 1"
check 2 "Specified-only functions" "= 0"
check 2 "Undefined and unspecified functions" "= 0"
check 2 "'Extern' global variables" "= 0"
check 2 "Potential entry points" "= 1"

echo "Finished checking libc metrics."
