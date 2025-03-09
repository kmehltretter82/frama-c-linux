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

log_file=$1
stats_file=$2

GREP="grep"
# Check if OS is macos 
if [[ "$OSTYPE" == "darwin"* ]]; then
    GREP="ggrep"
fi

function default_zero() {
    if [ -z "$1" ]; then
        echo "0"
    else
        echo "$1"
    fi
}

# Total number of functions where summaries were saved from previous analysis
function extract_saved_summaries() {
    local line=$($GREP -oP "\[eva\] In save file \K[^,]+, \K\d+ saved calls for \d+ functions" $log_file)
    local saved_summaries=$(echo "$line" | awk '{print $1}')
    local total_functions=$(echo "$line" | awk '{print $5}')

    echo "$(default_zero $total_functions)"
}

# Total number of functions where summaries were reloaded from previous analysis
function extract_reloaded_summaries() {
    local line=$($GREP -oP "\[eva\] In current session, \K\d+ saved calls for \d+ functions" $log_file)
    local reloaded_summaries=$(echo "$line" | awk '{print $1}')
    local total_functions=$(echo "$line" | awk '{print $5}')

    echo "$(default_zero $total_functions)"
}

# EVA analysis time
function extract_analysis_time() {
    local analysis_time=($($GREP -2 "Execution time per callstack" $log_file | tail -n 1 | $GREP -oe '\([0-9.]*\)'))
    local analysis_time=${analysis_time[1]}

    echo "$(default_zero $analysis_time)"
}

(
  printf 'sum_saved_fun=%s\n' $(extract_saved_summaries);
  printf 'sum_reloaded_fun=%s\n' $(extract_reloaded_summaries);
  printf 'eva_time=%s\n' $(extract_analysis_time);
) >> $stats_file

