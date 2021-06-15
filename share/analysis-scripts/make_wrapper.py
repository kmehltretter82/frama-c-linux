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

# This script serves as wrapper to 'make' (when using the analysis-scripts
# GNUmakefile template): it parses the output and suggests useful commands
# whenever it can, by calling frama-c-script itself.

import argparse
import os
import re
import subprocess
import sys
from functools import partial
import tempfile

MIN_PYTHON = (3, 6) # for automatic Path conversions
if sys.version_info < MIN_PYTHON:
    sys.exit("Python %s.%s or later is required.\n" % MIN_PYTHON)

parser = argparse.ArgumentParser(description="""
Builds the specified target, parsing the output to identify and recommend
actions in case of failure.""")
parser.add_argument('--make-dir', metavar='DIR', default=".frama-c",
                    help='directory containing the makefile (default: .frama-c)')

(make_dir_arg, args) = parser.parse_known_args()
make_dir = vars(make_dir_arg)["make_dir"]
args = args[1:]

framac_bin = os.getenv('FRAMAC_BIN')
if not framac_bin:
   sys.exit("error: FRAMAC_BIN not in environment (set by frama-c-script)")
framac_script = f"{framac_bin}/frama-c-script"

output_lines = []
cmd_list = ['make', "-C", make_dir] + args
with subprocess.Popen(cmd_list,
                      stdout=subprocess.PIPE,
                      stderr=subprocess.PIPE) as proc:
  while True:
    line = proc.stdout.readline()
    if line:
       sys.stdout.buffer.write(line)
       sys.stdout.flush()
       output_lines.append(line.decode('utf-8'))
    else:
       break

re_missing_spec = re.compile("Neither code nor specification for function ([^,]+),")
re_recursive_call_start = re.compile("detected recursive call")
re_recursive_call_end = re.compile("Use -eva-ignore-recursive-calls to ignore")

tips = []

lines = iter(output_lines)
for line in lines:
    match = re_missing_spec.search(line)
    if match:
       fname = match.group(1)
       def action(fname):
           out = subprocess.Popen([framac_script, "find-fun", "-C", make_dir, fname],
                                  stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
           output = out.communicate()[0].decode('utf-8')
           re_possible_definers = re.compile("Possible definitions for function")
           find_fun_lines = iter(output.splitlines())
           for find_fun_line in find_fun_lines:
              if re_possible_definers.match(find_fun_line):
                 found_files = [next(find_fun_lines)]
                 while True:
                    try:
                       found_files.append(next(find_fun_lines))
                    except StopIteration:
                       if len(found_files) > 1:
                          print("Found several files defining function '"
                                + fname + "', cannot recommend automatically.")
                          print("Check which one is appropriate and add it " +
                                "to the list of sources to be parsed:")
                          print("\n".join(found_files))
                       else:
                          print("Add the following file to the list of "
                                + "sources to be parsed:\n" + found_files[0])
                       return
           print("Could not find any files defining " + fname + ".")
           print("Find the sources defining it and add them, " +
                 "or provide a stub.")
       tip = {"message": "Found function with missing spec: " + fname + "\n" +
              "   Looking for files defining it...",
              "action":partial(action, fname)
       }
       tips.append(tip)
    else:
       match = re_recursive_call_start.search(line)
       if match:
          def action():
             print("Consider patching or stubbing the recursive call, " +
                   "then re-run the analysis.")
          msg_lines = []
          line = next(lines)
          while True:
             match = re_recursive_call_end.search(line)
             if match:
                tip = {"message": "Found recursive call at:\n" +
                       "\n".join(msg_lines),
                       "action":action
                       }
                tips.append(tip)
                break
             else:
                msg_lines.append(line)
                try:
                   line = next(lines)
                except StopIteration:
                   print("** Error: EOF without ending recursive call stack?")
                   assert False

if tips != []:
   print("")
   print("***** make-wrapper recommendations *****")
   print("")
   counter = 1
   print("*** recommendation #" + str(counter) + " ***")
   print("")
   for tip in tips:
      if counter > 1:
         print("")
         print("*** recommendation #" + str(counter) + " ***")
      print(str(counter) + ". " + tip["message"])
      counter += 1
      tip["action"]()
