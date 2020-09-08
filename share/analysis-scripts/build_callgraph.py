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

# This script finds files containing likely declarations and definitions
# for a given function name, via heuristic syntactic matching.

import sys
import os
import re
import glob
import function_finder

MIN_PYTHON = (3, 5) # for glob(recursive)
if sys.version_info < MIN_PYTHON:
    sys.exit("Python %s.%s or later is required.\n" % MIN_PYTHON)

debug = os.getenv("DEBUG")

arg = ""
if len(sys.argv) < 2:
   print(f"usage: {sys.argv[0]} [file1 file2 ...]")
   print("       builds a heuristic callgraph for the specified files.")
   sys.exit(1)
else:
   files = sys.argv[1:]


'''
re_fun = function_finder.prepare_definition_regex()
for f in files:
    (found, match) = function_finder.find_first_match(re_fun, f)
    if match:
       fname = match.group(1)
    else:
        print(f"No function declaration or definition found in {f} !")
    if found:
        if found == 1:
            print(f"Found declarator for {fname.upper()}, ignoring !")
        else:
            print(f"Found definition for {fname.upper()} !")
'''

re_function_def = function_finder.prepare_definition_regex()
re_function_call = r"[a-zA-Z_][a-zA-Z0-9_]*\s*\("
# here, get for each loop iteration a tuple (Match Object, int) of the name of the Match Object in file and it's line
# find_definitions is a generator function so appending all iterations results is to be expected in order to get a data_structure to further process
def function_definition_mapper(regex, File):
    return [x for x in function_finder.find_definitions(regex, File, 0)]

def function_calls_mapper(regex, File):
    return [x for x in function_finder.find_calls(regex, File, 0)]

# here starts the inspection of each of the files passed in command line
for f in files:
    if debug:
        print(f"Entering file {os.path.relpath(f)}:")
    function_defs = function_definition_mapper(re_function_def, f)
    if not function_defs:
        if debug:
            print(f"No call or potential call found in file {f} !")
        continue
    # function_ranges is a list of [name_function_def, (int, int)]
    # its size == len(function_defs)
    # name_function_def is a string
    # (int, int) is a tuple of that describe the range of name_function_def
    function_ranges = []
    [[function_ranges.append((element[0].group(1), (element[1], function_defs[i + 1][1] - 1)))\
    for i, element in enumerate(function_defs) if i < len(function_defs) - 1]]
    function_calls = function_calls_mapper(re_function_call,f)
    if not function_calls:
        print(f"No definition found in file {f} !")
        continue
    if debug:
        for i in range(len(function_ranges)):
            print(f"{function_ranges[i]}")
        print("\n")
        for i in range(len(function_calls)):
            print(f"{function_calls[i][0].group(0)} appears at line {function_calls[i][1]}")
        print("\n")
    func_def_calls = []
    # for each function call:
    #   Go through function_def list
    #       keep range of current function_def 
    #       check if current function call is in that range
    #       append a tuple (string, string, int) as (function_being_defined, function_being_called, line of function call) to the list
    for i in range(len(function_calls)):
        for index, e in enumerate(function_ranges):
            min_range, max_range = e[1]
            if min_range < function_calls[i][1] <= max_range:
                func_def_calls.append((e[0], function_calls[i][0].group(0)[:-1], function_calls[i][1]))
    for i in range(len(func_def_calls)):
        print(f"{os.path.relpath(f)}:{func_def_calls[i][2]}: {func_def_calls[i][0]} -> {func_def_calls[i][1]}")







