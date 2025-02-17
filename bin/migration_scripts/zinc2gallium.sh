#!/bin/bash
##########################################################################
#                                                                        #
#  This file is part of Frama-C.                                         #
#                                                                        #
#  Copyright (C) 2007-2025                                               #
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

#
# Converts a Frama-C plugin from Frama-C 30 Zinc to Frama-C 31 Gallium,
# on a best-efforts basis (no guarantee that the result is fully compatible).
#
# known missing features:
# - doesn't follow symbolic links to directories

DIR=

# verbose on by default
VERBOSE="v"

# test once if sed supports -i (BSD/macOS does not)
SED_HAS_I=$(sed --help 2>/dev/null | grep '\-i' 2>/dev/null)

# [sedi file expressions] runs 'sed -i expressions' on the specified file;
# if '-i' is not supported, creates a temporary file and overwrites the
# original, like '-i' does.
sedi ()
{
  file="$1"
  shift
  if [ -n "$SED_HAS_I" ]; then
    sed -i "$@" "$file"
  else
    # option '-i' is not recognized by sed: use a tmp file
    new_temp=`mktemp /tmp/frama-c.XXXXXXX` || exit 1
    sed "$@" "$file" > "$new_temp"
    mv -f "$new_temp" "$file"
  fi
}

dirs ()
{
  if [ -z "$DIR" ]; then
    DIR=.
  fi
}

# [safe_goto d1 d2 cmd] goes to d1, runs cmd, and returns to d2
safe_goto ()
{
  dir="$1"
  cd "$dir"
  $3
  cd "$2"
}

goto ()
{
  if [ -d "$1" ]; then
    safe_goto "$1" "$2" "$3"
  else
    echo "Directory '$1' does not exist. Omitted."
  fi
}

process_file ()
{
  file="$1"
  if [ "$VERBOSE" ]; then
    echo "Processing file $file"
  fi
  sedi "$file" \
   -e 's/Cil\.bitfield_attribute_name/Ast_attributes.bitfield_attribute_name/g' \
   -e 's/Cil\.anonymous_attribute_name/Ast_attributes.anonymous_attribute_name/g' \
   -e 's/Cil\.anonymous_attribute/Ast_attributes.anonymous_attribute/g' \
   -e 's/Cil\.frama_c_ghost_else/Ast_attributes.frama_c_ghost_else/g' \
   -e 's/Cil\.frama_c_ghost_formal/Ast_attributes.frama_c_ghost_formal/g' \
   -e 's/Cil\.frama_c_init_obj/Ast_attributes.frama_c_init_obj/g' \
   -e 's/Cil\.frama_c_mutable/Ast_attributes.frama_c_mutable/g' \
   -e 's/Cil\.frama_c_inlined/Ast_attributes.frama_c_inlined/g' \
   -e 's/Cil\.attributeName/Ast_attributes.attribute_name/g' \
   -e 's/Cil\.addAttribute/Ast_attributes.add/g' \
   -e 's/Cil\.addAttributes/Ast_attributes.add_list/g' \
   -e 's/Cil\.dropAttribute/Ast_attributes.drop/g' \
   -e 's/Cil\.dropAttributes/Ast_attributes.drop_list/g' \
   -e 's/Cil\.hasAttribute/Ast_attributes.contains/g' \
   -e 's/Cil\.findAttribute/Ast_attributes.find_params/g' \
   -e 's/Cil\.filterAttributes/Ast_attributes.filter/g' \
   -e 's/Cil\.registerAttribute/Ast_attributes.register/g' \
   -e 's/Cil\.removeAttribute/Ast_attributes.remove/g' \
   -e 's/Cil\.attributeClass/Ast_attributes.get_class/g' \
   -e 's/Cil\.isKnownAttribute/Ast_attributes.is_known/g' \
   -e 's/Cil\.partitionAttributes/Ast_attributes.partition/g' \
   -e 's/Cil\.filter_qualifier_attributes/Ast_attributes.filter_qualifiers/g' \
   -e 's/Cil\.splitArrayAttributes/Ast_attributes.split_array_attributes/g' \
   -e 's/Cil\.separateStorageModifiers/Ast_attributes.split_storage_modifiers/g'
   # this line left empty on purpose
}

apply_one_dir ()
{
  if [ "$VERBOSE" ]; then
    echo "Processing directory `pwd`"
  fi
  for f in $(find . -maxdepth 1 -type f -name "*.ml*" 2> /dev/null); do
    process_file "$f"
  done
}

apply_recursively ()
{
    apply_one_dir
    while IFS= read -r -d $'\0' d; do
        if [ "$d" = "." ]; then
            continue
        fi
        safe_goto "$d" .. apply_recursively
    done < <(find . -maxdepth 1 -type d -print0)
}

applying_to_list ()
{
  dirs
  tmpdir=`pwd`
  for d in $DIR; do
    goto "$d" "$tmpdir" "$1"
  done
}

help ()
{
  echo "Usage: $0 [options | directories]

Options are:
  -r | --recursive       Check subdirectories recursively
  -h | --help            Display help message
  -q | --quiet           Quiet mode (i.e. non-verbose mode)
  -v | --verbose         Verbose mode (default)"
  exit 0
}

error ()
{
  echo "$1.
Do \"$0 -h\" for help."
  exit 1
}

FN="apply_one_dir"

parse_arg ()
{
  case $1 in
    -r | --recursive)     FN="apply_recursively";;
    -h | -help      )     help; exit 0;;
    -q | --quiet    )     VERBOSE=;;
    -v | --verbose  )     VERBOSE="v";;
    -* )                  error "Invalid option $1";;
    * )                   DIR="$DIR $1";;
  esac
}

cmd_line ()
{
  for s in "$@"; do
    parse_arg "$s"
  done
  applying_to_list $FN
}

cmd_line "$@"
exit 0
