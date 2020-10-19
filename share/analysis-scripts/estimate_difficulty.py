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

# This script uses several heuristics to try and estimate the difficulty
# of analyzing a new code base with Frama-C.

import argparse
import build_callgraph
import function_finder
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

MIN_PYTHON = (3, 5)
if sys.version_info < MIN_PYTHON:
    sys.exit("Python %s.%s or later is required.\n" % MIN_PYTHON)

parser = argparse.ArgumentParser(description="""
Estimates the difficulty of analyzing a given code base""")
parser.add_argument("--header-dirs", "-d", metavar='DIR', nargs='+',
                    help='directories containing headers (default: .frama-c)')
parser.add_argument("files", nargs='+', help='source files')
args = vars(parser.parse_args())

header_dirs = args["header_dirs"]
if not header_dirs:
    header_dirs = []
files = args["files"]

# gather information from several sources

def extract_keys(l):
    return [list(key.keys())[0] for key in l]

def get_framac_libc_function_statuses(framac, framac_share):
    (_metrics_handler, metrics_tmpfile) = tempfile.mkstemp(prefix="fc_script_est_diff", suffix=".json")
    if debug:
        print(f"metrics_tmpfile: {metrics_tmpfile}")
    fc_runtime = framac_share / "libc" / "__fc_runtime.c"
    fc_libc_headers = framac_share / "libc" / "__fc_libc.h"
    subprocess.run([framac, "-no-autoload-plugins", fc_runtime, fc_libc_headers,
                    "-load-module", "metrics", "-metrics", "-metrics-libc",
                    "-metrics-output", metrics_tmpfile], stdout=subprocess.DEVNULL, check=True)
    with open(metrics_tmpfile) as f:
        metrics_json = json.load(f)
    os.remove(metrics_tmpfile)
    defined = extract_keys(metrics_json["defined-functions"])
    spec_only = extract_keys(metrics_json["specified-only-functions"])
    return (defined, spec_only)

include_exp_for_grep = r'\s*#\s*include\s*\("\|<\)\([^">]\+\)\("\|>\)'
include_exp_for_py = r'\s*#\s*include\s*("|<)([^">]+)("|>)'
re_include = re.compile(r'^(.*):(.*):' + include_exp_for_py)
def get_includes(files):
    quote_includes = {}
    chevron_includes = {}
    # adding /dev/null to the list of files ensures 'grep' will display the
    # file name for each match, even when a single file is given
    out = subprocess.Popen(["grep", "-n", "^" + include_exp_for_grep] + files + ["/dev/null"],
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    lines = out.communicate()[0].decode('utf-8').splitlines()
    for line in lines:
        m = re_include.match(line)
        assert m, f"grep found include but not Python: {line}"
        filename = m.group(1)
        line = m.group(2)
        kind = m.group(3)
        header = m.group(4)
        if kind == '<':
            includes = chevron_includes[header] if header in chevron_includes else []
        else:
            includes = quote_includes[header] if header in quote_includes else []
        includes.append((filename, line))
        if kind == '<':
            chevron_includes[header] = includes
        else:
            chevron_includes[header] = includes
    return chevron_includes, quote_includes

debug = os.getenv("DEBUG")
verbose = False

print("Building callgraph...")
cg = build_callgraph.compute(files)

framac_bin = os.getenv('FRAMAC_BIN')
if not framac_bin:
    sys.exit("error: FRAMAC_BIN not in environment")
framac = Path(framac_bin) / "frama-c"

framac_share = Path(subprocess.check_output([framac, '-no-autoload-plugins', '-print-share-path']).decode())

print("Computing data about libc/POSIX functions...")
libc_defined_functions, libc_specified_functions = get_framac_libc_function_statuses(framac, framac_share)

with open(framac_share / "compliance" / "c11_functions.json") as f:
    c11_functions = json.load(f)["data"]

with open(framac_share / "compliance" / "c11_headers.json") as f:
    c11_headers = json.load(f)["data"]

with open(framac_share / "compliance" / "posix_identifiers.json") as f:
    all_data = json.load(f)
    posix_identifiers = all_data["data"]
    posix_headers = all_data["headers"]

recursive_cycles = []
build_callgraph.compute_recursive_cycles(cg, recursive_cycles)
for (cycle_start_loc, cycle) in recursive_cycles:
    (filename, line) = cycle_start_loc
    (x, y) = cycle[0]
    pretty_cycle = f"{x} -> {y}"
    for (x, y) in cycle[1:]:
        pretty_cycle += f" -> {y}"
    print(f"[recursion] found recursive cycle near {filename}:{line}: {pretty_cycle}")

callees = [callee for (_, callee) in list(cg.edges.keys())]
callees = set(callees)
used_headers = set()
print(f"Estimating difficulty for {len(callees)} function calls...")
warnings = 0
for callee in sorted(callees):
    #print(f"callee: {callee}")
    if callee in posix_identifiers:
        used_headers.add(posix_identifiers[callee]["header"])
    if callee in c11_functions:
        # check that the callee is not a macro or type (e.g. va_arg)
        if posix_identifiers[callee]["id_type"] != "function":
            continue
        #print(f"C11 function: {callee}")
        if callee in libc_specified_functions:
            if verbose or debug:
                print(f"- good: {callee} (C11) is specified in Frama-C's libc")
        elif callee in libc_defined_functions:
            if verbose or debug:
                print(f"- ok: {callee} (C11) is defined in Frama-C's libc")
        else:
            # Some functions without specification are actually variadic
            # (and possibly handled by the Variadic plug-in)
            if "notes" in posix_identifiers[callee] and "variadic-plugin" in posix_identifiers[callee]["notes"]:
                if verbose or debug:
                    print(f"- ok: {callee} (C11) is handled by the Variadic plug-in")
            else:
                warnings += 1
                print(f"- warning: {callee} (C11) has neither code nor spec in Frama-C's libc")
    elif callee in posix_identifiers:
        # check that the callee is not a macro or type (e.g. va_arg)
        if posix_identifiers[callee]["id_type"] != "function":
            continue
        #print(f"Non-C11, POSIX function: {callee}")
        if callee in libc_specified_functions:
            if verbose or debug:
                print(f"- good: {callee} (POSIX) specified in Frama-C's libc")
        elif callee in libc_defined_functions:
            if verbose or debug:
                print(f"- ok: {callee} (POSIX) defined in Frama-C's libc")
        else:
            warnings += 1
            print(f"- warning: {callee} (POSIX) has neither code nor spec in Frama-C's libc")
print(f"Function-related warnings: {warnings}")

if (verbose or debug) and used_headers:
    print(f"used headers:")
    for header in sorted(used_headers):
        print(f"  <{header}>")

(chevron_includes, quote_includes) = get_includes(files)

def is_local_header(header_dirs, header):
    for d in header_dirs:
        path = Path(d)
        if Path(path / header).exists():
            return True
    return False

print(f"Estimating difficulty for {len(chevron_includes)} '#include <header>' directives...")
non_posix_headers = []
for header in chevron_includes:
    if header in posix_headers:
        fc_support = posix_headers[header]["fc-support"]
        if fc_support == "unsupported":
            print(f"- WARNING: included header <{header}> is explicitly unsupported by Frama-C")
        elif fc_support == "none":
            print(f"- warning: included header <{header}> not currently included in Frama-C's libc")
        else:
            if verbose or debug:
                c11_or_posix = "C11" if header in c11_headers else "POSIX"
                print(f"- note: included {c11_or_posix} header ")
    else:
        if is_local_header(header_dirs, header):
            if verbose or debug:
                print(f"- ok: included header <{header}> seems to be available locally")
        else:
            non_posix_headers.append(header)
            print(f"- warning: included non-POSIX header <{header}>")
print(f"Header-related warnings: {len(non_posix_headers)}")


# dynamic allocation

dynalloc_functions = set(["malloc", "calloc", "free", "realloc", "alloca", "mmap"])
dyncallees = dynalloc_functions.intersection(callees)
if dyncallees:
    print(f"- note: calls to dynamic allocation functions: {', '.join(sorted(dyncallees))}")


# unsupported C11-specific features

c11_unsupported = ["_Alignas", "_Alignof", "_Generic", "_Static_assert"]

for keyword in c11_unsupported:
    out = subprocess.Popen(["grep", "-n", '\\b' + keyword + '\\b'] + files + ["/dev/null"],
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    lines = out.communicate()[0].decode('utf-8').splitlines()
    if lines:
        n = len(lines)
        print(f"- warning: found {n} line{'s' if n > 1 else ''} with occurrences of unsupported C11 construct '{keyword}'")

# TODO:
# - detect absence of 'main' function (library)
