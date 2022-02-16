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

# This file provides some functions to open and filter source files
# before they are used by other scripts. These filters help improve
# the efficiency of regex-based heuristics.

# These filters require external tools, either in the PATH, or in
# environment variables (the latter has higher priority than the former).
# - scc (a fork including option -k), to remove C comments (variable SCC);
# - astyle, to re-indent lines (variable ASTYLE)
# If a tool is absent, the filter is equivalent to a no-op.

# These functions receive a file object (such as produced by open(),
# subprocess.run, or a previous filter) and return a
# file object containing the output. They abort execution in case
# of errors when running the filters. Note that an absent tool
# does _not_ lead to an error.

import os
from   pathlib import Path
import shutil
import subprocess
import sys

# warnings about missing commands are disabled during testing
emit_warns = os.getenv("PTESTS_TESTING") == None

# Returns a Path to the command binary, or None if it is not found
# Emits a warning the first time it looks for a command
warned = {}
def get_command(command, env_var_name):
    p = os.getenv(env_var_name)
    if not p:
        p = shutil.which(command)
    if not p:
        if emit_warns and command not in warned:
            print(f"info: optional external command '{command}' not found in PATH; consider installing it or setting environment variable {env_var_name}")
            warned[command] = True
        return None
    return Path(p)

def run_and_check(command_and_args, input_data):
    try:
        return subprocess.check_output(command_and_args, input=input_data, stderr=None, encoding="ascii", errors="ignore")
    except subprocess.CalledProcessError as e:
        sys.exit(f"error running command: {command_and_args}\n{e}")

def filter_with_scc(input_data):
    scc = get_command("scc", "SCC")
    if scc:
        return run_and_check([scc, "-k"], input_data)
    else:
        return input_data

def filter_with_astyle(input_data):
    astyle = get_command("astyle", "ASTYLE")
    if astyle:
        return run_and_check([astyle, "--keep-one-line-blocks", "--keep-one-line-statements"], input_data)
    else:
        return input_data

def open_and_filter(filename, apply_filters):
    # we ignore encoding errors and use ASCII to avoid issues when
    # opening files with different encodings (UTF-8, ISO-8859, etc)
    with open(filename, "r", encoding="ascii", errors='ignore') as f:
        data = f.read()
    if apply_filters:
        data = filter_with_astyle(filter_with_scc(data))
    return data
