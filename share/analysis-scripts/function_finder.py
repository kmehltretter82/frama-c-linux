#!/usr/bin/env python3
#-*- coding: utf-8 -*-
##########################################################################
#                                                                        #
#  This file is part of Frama-C.                                         #
#                                                                        #
#  Copyright (C) 2007-2020                                               #
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

# Exports find_function_in_file, to be used by other scripts

import re

# To minimize the amount of false positives, we try to match the following:
# - the line must begin with a C identifier (declarations and definitions in C
#   rarely start with spaces in the line), or with the function name itself
#   (supposing the return type is in the previous line)
# - any number of identifiers are allowed (to allow for 'struct', 'volatile',
#   'extern', etc)
# - asterisks are allowed both before and after identifiers, except for the
#   first one (to allow for 'char *', 'struct **ptr', etc)
# - identifiers are allowed after the parentheses, to allow for some macros/
#   modifiers

# Precomputes the regex for 'fname'
def prepare(fname):
    c_identifier = "[a-zA-Z_][a-zA-Z0-9_]*"
    c_id_maybe_pointer = c_identifier + "\**"
    type_prefix = c_id_maybe_pointer + "(?:\s+\**" + c_id_maybe_pointer + ")*\s+\**"
    parentheses_suffix = "\s*\([^)]*\)"
    re_fun = re.compile("^(?:" + type_prefix + "\s*)?" + fname + parentheses_suffix
                        + "\s*(?:" + c_identifier + ")?\s*(;|{)", flags=re.MULTILINE)
    return re_fun

# Returns 0 if not found, 1 if declaration, 2 if definition
def find(prepared_re, f):
   with open(f, encoding="ascii", errors='ignore') as content_file:
      content = content_file.read()
      has_decl_or_def = prepared_re.search(content)
      if has_decl_or_def is None:
          return 0
      else:
         is_decl = has_decl_or_def.group(1) == ";"
         return 1 if is_decl else 2

# Precomputes the regex for a function
def prepare_definition_regex():
    c_identifier = "[a-zA-Z_][a-zA-Z0-9_]*"
    c_id_maybe_pointer = c_identifier + "\**"
    type_prefix = c_id_maybe_pointer + "(?:\s+\**" + c_id_maybe_pointer + ")*\s+\**"
    parentheses_suffix = "\s*\([^)]*\)"
    re_fun = re.compile("^(?:" + type_prefix + "\s*)?" + "([a-zA-Z_][a-zA-Z0-9_]*)" + parentheses_suffix
                        + "\s*(?:" + c_identifier + ")?\s*(;|{)", flags=re.MULTILINE)
    return re_fun

# Returns tuple (0, None) if not found, (1, match) if declaration, (2, match) if definition
# Returns only at the first match of {prepared_re} regex in file {f}, not iterable unlike find3 function
def find_first_match(prepared_re, f):
   with open(f, encoding="ascii", errors='ignore') as content_file:
      content = content_file.read()
      match = prepared_re.search(content)
      if match is None:
          return (0, None)
      else:
         is_decl = match.group(2) == ";"
         return (1, match) if is_decl else (2, match)


def find_definitions(pattern, f, flags):
    with open(f, encoding="ascii", errors='ignore') as content_file:
        content = content_file.read()
        # create a list of Match objects that fit "pattern" regex
        matches = list(re.finditer(pattern, content, flags))
        if not matches:
            return (None, 0)
        # keep the offset of the last occurence of the matching pattern in the content string
        # to avoiding checking past the last occurence in the newline_table
        end = matches[-1].start()
        newline_table = {-1: 0}
        for i, m in enumerate(re.finditer(r'\n', content, 1)):
            offset = m.start()
            if offset > end:
                break
            # + 1 because convention states lines in a file start at 1
            # + 1 because we are counting newlines
            newline_table[offset] = i + 1 + 1
    for m in matches:
        newline_offset = content.rfind('\n', 0, m.start())
        # delete declarator and corresponding newline_table element if a ; is found instead of {
        if m.group(2) == ';':
            del(newline_table[newline_offset])
            del(m)
        else:
            line_number = newline_table[newline_offset]
            yield (m, line_number)
    return (None, 0)

def find_calls(pattern, f, flags):
    with open(f, encoding="ascii", errors='ignore') as content_file:
        content = content_file.read()
        # create a list of Match objects that fit "pattern" regex
        matches = list(re.finditer(pattern, content, flags))
        if not matches:
            return (None, 0)
        # Here, we filter all occurences of C keywords captured as possible func calls
        # replace `filtre` assignement by a more exhaustive list for better results
        filtre = ["if", "return", "while", "for"]
        matches = [n for n in matches if not any(m in n[0] for m in filtre)]

        # keep the offset of the last occurence of the matching pattern in the content string
        # to avoiding checking past the last occurence in the newline_table
        end = matches[-1].start()
        newline_table = {-1: 0}
        for i, m in enumerate(re.finditer(r'\n', content, 1)):
            offset = m.start()
            if offset > end:
                break
            # + 1 because convention states lines in a file start at 1
            # + 1 because we are counting newlines
            newline_table[offset] = i + 1 + 1
 
    for m in matches:
        newline_offset = content.rfind('\n', 0, m.start())
        line_number = newline_table[newline_offset]
        yield (m, line_number)
    return (None, 0)
