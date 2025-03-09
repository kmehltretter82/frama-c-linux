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

stat_file=$1
stats_file=$2
save_file=$3

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

sum_hits=$(default_zero $(grep "cache-hits" $stat_file | awk '{print $2}'))
sum_misses=$(default_zero $(grep "cache-misses" $stat_file | awk '{print $2}'))

inv_reused=$(default_zero $(grep "reused-widenings" $stat_file | awk '{print $2}'))
inv_saved=$(default_zero $(grep "memexec-saved-widenings" $stat_file | awk '{print $2}'))

total_iterations=$(default_zero $(grep "total-iterations" $stat_file | awk '{print $2}'))

# Load time
cache_load=$(default_zero $(grep "time-memexec-import-cache" $stat_file | awk '{print $2}'))
ast_diff=$(default_zero $(grep "time-ast-diff-compute" $stat_file| awk '{print $2}'))

# Import time of cache contains ast_diff time, and they are in ms
if [ "$cache_load" -ne "0" ]; then
    cache_load=$((cache_load - ast_diff))
    cache_load=$((cache_load / 1000))
    ast_diff=$((ast_diff / 1000))
fi

# Cache file size
filesize=$(default_zero $(stat --printf="%s" $save_file))
filesize_mb=$(echo "scale=2; $filesize / 1024 / 1024" | bc)

(
    printf 'sum_hits=%s\n' $sum_hits;
    printf 'sum_misses=%s\n' $sum_misses;
    printf 'inv_reused=%s\n' $inv_reused;
    printf 'inv_saved=%s\n' $inv_saved;
    printf 'total_iterations=%s\n' $total_iterations;
    printf 'cache_load=%s\n' $cache_load;
    printf 'ast_diff=%s\n' $ast_diff;
    printf 'filesize_mb=%s\n' $filesize_mb;
) >> $stats_file

