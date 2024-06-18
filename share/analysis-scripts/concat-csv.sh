#!/bin/bash -eu
##########################################################################
#                                                                        #
#  This file is part of Frama-C.                                         #
#                                                                        #
#  Copyright (C) 2007-2024                                               #
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

set -o pipefail

header_column=""
delete_first=""
sort=""
files=""
show_usage=""

while [[ $# > 0 ]]
do
    case $1 in
        --add-header-column)
            header_column="yes"
            ;;

        --delete-first)
            delete_first="$2"
            shift
            ;;

        --sort)
            sort="yes"
            ;;

        -h|--help)
            show_usage="yes"
            ;;

        *)
            files="$files $1"
            ;;
    esac
    shift
done

target=""
sources=""
read target sources <<<$files

if [ -z "$sources" -o -n "$show_usage" ]
then
    echo "Usage: $0 TARGET SOURCE1 ..."
    echo "Concat and/or transform CSV files."
    echo ""
    echo "The following arguments can be given:"
    echo "      --add-header-column,    add a header column consisting of the base name of"
    echo "                              the CSV file"
    echo "      --delete-first N        delete the first N columns"
    echo "      --sort                  sort the CSV file"
    echo "  -h, --help                  prints this help and quits"
    exit 1
fi


# Read header line
read first rest <<<$sources
header=$(head --quiet --lines 1 $first)
if [ -n "$header_column" ]
then
  header="project	$header"
fi
if [ -n "$delete_first" ]
then
  header=$(cut -f1-$delete_first --complement <<<"$header")
fi
# Read sources
{
  for f in $sources
  do
    if [ -n "$header_column" ]
    then
      base=$(basename "$f")
      project="${base%%.*}"
      sed -e '1d' -e "s/^/$project\t/" "$f";
    else
      sed -e '1d' "$f";
    fi
  done
} |
# Remove first columns
{
  if [ -n "$delete_first" ]
  then
    cut -f1-$delete_first --complement
  else
    cat
  fi
} |
# Remove blanks
sed '/^$/d' |
# Sort the file
{
  echo "$header"
  if [ -n $sort ]
  then
    sort -u
  else
    cat
  fi
} > "$target"

