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

# This script parses a compile_commands.json[1] file and lists the C files
# in it.
#
# [1] See: http://clang.llvm.org/docs/JSONCompilationDatabase.html

import sys
import os
import json
import re
from pathlib import Path

MIN_PYTHON = (3, 6) # for glob(recursive) and automatic Path conversions
if sys.version_info < MIN_PYTHON:
    sys.exit("Python %s.%s or later is required.\n" % MIN_PYTHON)

if len(sys.argv) < 2:
   # no argument, assume default name
   arg = Path("compile_commands.json")
else:
   arg = Path(sys.argv[1])

if not arg.exists():
   print(f"error: file '{arg}' not found")
   sys.exit(f"usage: {sys.argv[0]} [compile_commands.json]")

# check if arg has a known extension
def is_known_c_extension(ext):
   return ext == ".c" or ext == ".i" or ext == ".h"

pwd = os.getcwd()
fcmake_pwd = pwd / Path(".frama-c") # pwd as seen by the Frama-C makefile
json = json.loads(open(arg).read())
jcdb_dir = arg.parent
includes = set()
defines = set()
files = set() # set of pairs of (file, file_for_fcmake)
for entry in json:
   arg_includes = [] # before normalization
   if not "file" in entry:
       # ignore entries without a filename
       continue
   file = Path(entry["file"])
   dir = Path(entry["directory"]) if "directory" in entry else None
   if file.is_absolute():
      filepath = file
   elif dir and dir.is_absolute():
      filepath = dir / file
   elif dir:
      filepath = jcdb_dir / dir / file
   else:
      filepath = jcdb_dir / file
   if not is_known_c_extension(filepath.suffix):
      print(f"warning: ignoring file of unknown type: {filepath}")
   else:
      files.add((os.path.relpath(filepath, pwd), os.path.relpath(filepath, fcmake_pwd)))

files_for_fcmake = map (lambda x:(x[1]), files)
print("# Paths as seen by a makefile inside subdirectory '.frama-c':")
print("SRCS=\\\n" + " \\\n".join(sorted(files_for_fcmake)) + " \\")
print("")

files_defining_main = set()
re_main = re.compile("(int|void)\s+main\s*\([^)]*\)\s*\{")
for (file, file_for_fcmake) in files:
   assert os.path.exists(file), "file does not exist: %s" % file
   with open(file, 'r') as content_file:
      content = content_file.read()
      res = re.search(re_main, content)
      if res is not None:
         files_defining_main.add(file_for_fcmake)

if files_defining_main != []:
   print("")
   print("# Possible definition of main function in the following file(s), as seen from '.frama-c':")
   print("\n".join(sorted(files_defining_main)))
