#!/usr/bin/env python3
#-*- coding: utf-8 -*-
##########################################################################
#                                                                        #
#  This file is part of Frama-C.                                         #
#                                                                        #
#  Copyright (C) 2007-2021                                               #
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

# This script uses heuristics to list all function definitions and
# declarations in a set of files.

import sys
import os
import re
import function_finder

MIN_PYTHON = (3, 5) # for glob(recursive)
if sys.version_info < MIN_PYTHON:
    sys.exit("Python %s.%s or later is required.\n" % MIN_PYTHON)

debug = bool(os.getenv("DEBUG", False))

arg = ""
if len(sys.argv) < 4:
   print("usage: %s want_defs want_decls file..." % sys.argv[0])
   print("       looks for likely function definitions and/or declarations")
   print("       in the specified files.")
   sys.exit(1)

def boolish_string(s):
    if s.lower() == "true" or s == "1":
        return True
    if s.lower() == "false" or s == "0":
        return False
    sys.exit(f"error: expected 'true', 'false', 0 or 1; got: {s}")

want_defs = boolish_string(sys.argv[1])
want_decls = boolish_string(sys.argv[2])
files = sys.argv[3:]

for f in files:
    newlines = function_finder.compute_newline_offsets(f)
    defs_and_decls = function_finder.find_definitions_and_declarations(want_defs, want_decls, f, newlines)
    for (funcname, is_def, start, end, _offset) in defs_and_decls:
        if is_def:
            print(f"{os.path.relpath(f)}:{start}:{end}: {funcname} (definition)")
        else:
            print(f"{os.path.relpath(f)}:{start}:{end}: {funcname} (declaration)")
