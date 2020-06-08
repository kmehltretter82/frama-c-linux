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

# This script is used to interactively fill template.mk, converting it
# into a GNUmakefile ready for analysis.

import sys
import os
import re
import shutil
import shlex
import glob
from subprocess import Popen, PIPE
from pathlib import Path

MIN_PYTHON = (3, 6) # for glob(recursive) and automatic Path conversions
if sys.version_info < MIN_PYTHON:
    sys.exit("Python %s.%s or later is required.\n" % MIN_PYTHON)

if len(sys.argv) > 2:
    print(f"usage: {sys.argv[0]} [dir]")
    print("       creates a Frama-C makefile in [dir] (default: .frama-c)")
    sys.exit(1)

framac="frama-c"
if not shutil.which(framac):
    if os.environ.get("FRAMAC"):
        framac = os.environ["FRAMAC"]
    else:
        sys.exit("error: frama-c must be in the PATH, "\
                 "or in environment variable FRAMAC")

jcdb = Path("compile_commands.json")

dir = Path(sys.argv[1] if len(sys.argv) == 2 else ".frama-c")
fc_stubs_c = dir / "fc_stubs.c"
gnumakefile = dir / "GNUmakefile"

print(f"Preparing template: {gnumakefile}")

# relative prefix, due to GNUmakefile possibly being in a sub-directory of PWD
relprefix = os.path.relpath(os.getcwd(), dir)

if "PTESTS_TESTING" in os.environ:
    print("Running ptests: setting up mock files...")
    jcdb.touch()
    Path(dir).mkdir(parents=True, exist_ok=True)
    fc_stubs_c.touch()
    gnumakefile.touch()

bindir = Path(os.path.dirname(os.path.abspath(framac)))
frama_c_config = bindir / "frama-c-config"
process = Popen([frama_c_config, "-print-share-path"], stdout=PIPE)
(output, err) = process.communicate()
output = output.decode('utf-8')
exit_code = process.wait()
if exit_code != 0:
    sys.exit("error running frama-c-config")
sharedir = Path(output)

def get_known_machdeps():
    process = Popen([bindir / "frama-c", "-machdep", "help"], stdout=PIPE)
    (output, err) = process.communicate()
    output = output.decode('utf-8')
    exit_code = process.wait()
    if exit_code != 0:
        sys.exit("error getting machdeps: " + output)
    match = re.match("\[kernel\] supported machines are (.*) \(default is (.*)\).", output, re.DOTALL)
    if not match:
        sys.exit("error getting known machdeps: " + output)
    machdeps = match.group(1).split()
    default_machdep = match.group(2)
    return (default_machdep, machdeps)

def check_path_exists(path):
    if os.path.exists(path):
        yn = input(f"warning: {path} already exists. Overwrite? [y/N] ")
        if yn == "" or not (yn[0] == "Y" or yn[0] == "y"):
            print("Exiting without overwriting.")
            sys.exit(0)
    pathdir = os.path.dirname(path)
    if not os.path.exists(pathdir):
        yn = input(f"warning: directory '{pathdir}' does not exit. Create it? [y/N] ")
        if yn == "" or not (yn[0] == "Y" or yn[0] == "y"):
            print("Exiting without creating.")
            sys.exit(0)
        Path(pathdir).mkdir(parents=True, exist_ok=False)

check_path_exists(gnumakefile)
main = input("Main target name: ")
if not re.match("^[a-zA-Z_0-9]+$", main):
    sys.exit("error: invalid main target name (can only contain letters, digits, dash or underscore)")

def expand_and_normalize_sources(expression, relprefix):
    subexps = shlex.split(expression)
    sources_lists = [glob.glob(exp, recursive=True) for exp in subexps]
    sources = sorted(set([item for sublist in sources_lists for item in sublist]))
    return [f"  {source} \\" if os.path.isabs(source) else f"  {relprefix}/{source} \\" for source in sources]

while True:
    sources = input("Source files (default: **/*.c): ")
    if not sources:
        sources="**/*.c"
    source_list = expand_and_normalize_sources(sources, relprefix)
    if not source_list:
        print(f"error: no sources were matched for '{sources}'.")
    else:
        print(f"The following sources were matched (relative to {dir}):")
        print("\n".join(source_list))
        print()
        yn = input("Is this ok? [Y/n] ")
        if yn == "" or not (yn[0] == "N" or yn[0] == "n"):
            break

json_compilation_database = None
if jcdb.is_file():
    yn = input("compile_commands.json exists, add option -json-compilation-database? [Y/n] ")
    if yn == "" or not (yn[0] == "N" or yn[0] == "n"):
        json_compilation_database = "."
    else:
        print("Option not added; you can later add it to FCFLAGS.")

add_main_stub = False
yn = input("Add stub for function main (only needed if it uses command-line arguments)? [y/N] ")
if yn != "" and (yn[0] == "Y" or yn[0] == "y"):
    add_main_stub = True

print("Please define the architectural model (machdep) of the target machine.")
(default_machdep, machdeps) = get_known_machdeps()
print("Known machdeps: " + " ".join(machdeps))
machdep_chosen = False
while not machdep_chosen:
    machdep = input(f"Please enter the machdep [{default_machdep}]: ")
    if not machdep:
        machdep = default_machdep
        machdep_chosen = True
    else:
        if not (machdep in machdeps):
            yn = input(f"'{machdep}' is not a standard machdep. Proceed anyway? [y/N]")
            if yn != "" and (yn[0] == "Y" or yn[0] == "y"):
                machdep_chosen = True
        else:
            machdep_chosen = True

def insert_line_after(lines, line_pattern, newline):
    re_line = re.compile(line_pattern)
    for i in range(0, len(lines)):
        if re_line.search(lines[i]):
            lines.insert(i+1, newline)
            return lines
    sys.exit(f"error: no lines found matching pattern: {line_pattern}")

def replace_line(lines, line_pattern, value, all_occurrences=False):
    replaced = False
    re_line = re.compile(line_pattern)
    for i in range(0, len(lines)):
        if re_line.search(lines[i]):
            lines[i] = value
            replaced = True
            if not all_occurrences:
                return lines
    if replaced:
        return lines
    else:
        sys.exit(f"error: no lines found matching pattern: {line_pattern}")

def remove_lines_between(lines, start_pattern, end_pattern):
    re_start = re.compile(start_pattern)
    re_end = re.compile(end_pattern)
    first_to_remove = -1
    last_to_remove = -1
    for i in range(0, len(lines)):
        if first_to_remove == -1 and re_start.search(lines[i]):
            first_to_remove = i
        elif re_end.search(lines[i]):
            last_to_remove = i
            break
    if first_to_remove == -1:
        sys.exit("error: could not find start pattern: " + start_pattern)
    elif last_to_remove == -1:
        sys.exit("error: could not find end pattern: " + end_pattern)
    return (lines[:first_to_remove-1] if first_to_remove > 0 else []) + (lines[last_to_remove+1:] if last_to_remove < len(lines)-1 else [])

with open(sharedir / "analysis-scripts" / "template.mk") as f:
    lines = list(f)
    lines = replace_line(lines, "^MACHDEP = .*", f"MACHDEP = {machdep}\n")
    if add_main_stub:
        lines = insert_line_after(lines, "^main.parse: \\\\", f"  fc_stubs.c \\\n")
        check_path_exists(fc_stubs_c)
        shutil.copyfile(sharedir / "analysis-scripts" / "fc_stubs.c", fc_stubs_c)
        lines = insert_line_after(lines, "^FCFLAGS", "  -main eva_main \\\n")
        print(f"Created stub for main function: {dir / 'fc_stubs.c'}")
    lines = replace_line(lines, "^main.parse: \\\\", f"{main}.parse: \\\n")
    lines = replace_line(lines, "^TARGETS = main.eva", f"TARGETS = {main}.eva\n")
    lines = replace_line(lines, "^  main.c \\\\", "\n".join(source_list) + "\n")
    if json_compilation_database:
      lines = insert_line_after(lines, "^FCFLAGS", f"  -json-compilation-database {json_compilation_database} \\\n")
    if relprefix != "..":
        lines = replace_line(lines, "^  -add-symbolic-path=.:.. \\\\", f"  -add-symbolic-path=.:{relprefix} \\\n", all_occurrences=True)

gnumakefile.write_text("".join(lines))

print(f"Template created: {gnumakefile}")

if "PTESTS_TESTING" in os.environ:
    print("Running ptests: cleaning up after tests...")
    jcdb.unlink()
    fc_stubs_c.unlink()
    # gnumakefile is not erased because we want it as an oracle
