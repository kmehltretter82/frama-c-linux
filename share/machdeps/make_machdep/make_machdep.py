#!/usr/bin/env python
##########################################################################
#                                                                        #
#  This file is part of Frama-C.                                         #
#                                                                        #
#  Copyright (C) 2007-2023                                               #
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

"""
Produces a machdep.yaml file for a given architecture.

Prerequisites:

- A C11-compatible (cross-)compiler (with support for _Generic),
- A (cross-)compiler supporting _Static_assert
- A (cross-)compiler supporting _Alignof or alignof

This script tries to compile several source files to extract the
information we need in terms of sizeof, alignof and representation
of the various types defined by the standard (e.g. size_t, wchar_t, ...)

In case some values are not identified, the YAML format can be edited
by hand afterwards.
"""

import argparse
import yaml
import json
from pathlib import Path
import re
import subprocess
import sys
import warnings

my_path = Path(sys.argv[0]).parent

parser = argparse.ArgumentParser(prog="make_machdep")
parser.add_argument("-v", "--verbose", action="store_true")
parser.add_argument("-o", default=sys.stdout, type=argparse.FileType("w"), dest="dest_file")
parser.add_argument("--compiler", default="cc", help="which compiler to use; default is 'cc'")
parser.add_argument(
    "--compiler-version",
    default="--version",
    help="option to pass to the compiler to obtain its version; default is --version",
)

parser.add_argument(
    "--from-file",
    help="reads compiler and arch flags from existing yaml file. Use -i to update it in place",
)
parser.add_argument(
    "-i",
    "--in-place",
    action="store_true",
    help="when reading compiler config from yaml, update the file in place. unused otherwise",
)

parser.add_argument(
    "--cpp-arch-flags",
    nargs="+",
    action="extend",
    help="architecture-specific flags needed for preprocessing, e.g. '-m32'",
)
parser.add_argument(
    "--compiler-flags",
    nargs="+",
    action="extend",
    type=str,
    help="flags to be given to the compiler (other than those set by --cpp-arch-flags); default is '-c'",
)
parser.add_argument("--check", action="store_true")

args, other_args = parser.parse_known_args()

if not args.compiler_flags:
    args.compiler_flags = ["-c"]


if args.from_file:
    orig_file = open(args.from_file, "r")
    orig_machdep = yaml.safe_load(orig_file)
    orig_file.close()
    if not "compiler" in orig_machdep or not "cpp_arch_flags" in orig_machdep:
        raise Exception("Missing fields in yaml file")
    args.compiler = orig_machdep["compiler"]
    if isinstance(orig_machdep["cpp_arch_flags"], list):
        args.cpp_arch_flags = orig_machdep["cpp_arch_flags"]
    else:  # old version of the schema used a single string
        args.cpp_arch_flags = orig_machdep["cpp_arch_flags"].split()


def print_machdep(machdep):
    if args.in_place:
        args.dest_file = open(args.from_file, "w")
    yaml.dump(machdep, args.dest_file, indent=4, sort_keys=True)
    # Python does not end the dump with a newline by itself
    args.dest_file.write("\n")


def check_machdep(machdep):
    try:
        from jsonschema import validate, ValidationError

        schema_filename = my_path.parent / "machdep-schema.json"

        with open(schema_filename, "r") as schema:
            validate(machdep, json.load(schema))
    except ImportError:
        warnings.warn("jsonschema is not available: no validation will be performed")
    except OSError:
        warnings.warn(f"error opening {schema_filename}: no validation will be performed")
    except ValidationError:
        warnings.warn("machdep object is not conforming to machdep schema")


# This must remain synchronized with cil_types.ml's 'mach' type
machdep = {
    "sizeof_short": None,
    "sizeof_int": None,
    "sizeof_long": None,
    "sizeof_longlong": None,
    "sizeof_ptr": None,
    "sizeof_float": None,
    "sizeof_double": None,
    "sizeof_longdouble": None,
    "sizeof_void": None,
    "sizeof_fun": None,
    "size_t": None,
    "wchar_t": None,
    "ptrdiff_t": None,
    "alignof_short": None,
    "alignof_int": None,
    "alignof_long": None,
    "alignof_longlong": None,
    "alignof_ptr": None,
    "alignof_float": None,
    "alignof_double": None,
    "alignof_longdouble": None,
    "alignof_str": None,
    "alignof_fun": None,
    "char_is_unsigned": None,
    "little_endian": None,
    "alignof_aligned": None,
    "has__builtin_va_list": None,
    "compiler": None,
    "cpp_arch_flags": None,
    "version": None,
}

compilation_command = [args.compiler] + args.cpp_arch_flags + args.compiler_flags

source_files = [
    ("sizeof_short.c", "number"),
    ("sizeof_int.c", "number"),
    ("sizeof_long.c", "number"),
    ("sizeof_longlong.c", "number"),
    ("sizeof_ptr.c", "number"),
    ("sizeof_float.c", "number"),
    ("sizeof_double.c", "number"),
    ("sizeof_longdouble.c", "number"),
    ("sizeof_void.c", "number"),
    ("sizeof_fun.c", "number"),
    ("alignof_short.c", "number"),
    ("alignof_int.c", "number"),
    ("alignof_long.c", "number"),
    ("alignof_longlong.c", "number"),
    ("alignof_ptr.c", "number"),
    ("alignof_float.c", "number"),
    ("alignof_double.c", "number"),
    ("alignof_longdouble.c", "number"),
    ("alignof_fun.c", "number"),
    ("alignof_str.c", "number"),
    ("alignof_aligned.c", "number"),
    ("size_t.c", "type"),
    ("wchar_t.c", "type"),
    ("ptrdiff_t.c", "type"),
    ("char_is_unsigned.c", "bool"),
    ("little_endian.c", "bool"),
    ("has__builtin_va_list.c", "has__builtin_va_list"),
]


def find_value(name, typ, output):
    if typ == "bool":
        expected = "(True|False)"

        def conversion(x):
            return x == "True"

    elif typ == "number":
        expected = "([0-9]+)"

        def conversion(x):
            return int(x)

    elif typ == "type":
        expected = "`([^`]+)`"

        def conversion(x):
            return x

    else:
        warnings.warn(f"unexpected type '{typ}' for field '{name}', skipping")
        return
    msg = re.compile(name + " is " + expected)
    res = re.search(msg, output)
    if res:
        if name in machdep:
            value = conversion(res.group(1))
            if args.verbose:
                print(f"[INFO] setting {name} to {value}")
            machdep[name] = value
        else:
            warnings.warn(f"unexpected symbol '{name}', ignoring")
    else:
        warnings.warn(f"cannot find value of field '{name}', skipping")
        if args.verbose:
            print(f"compiler output is:{output}")


for (f, typ) in source_files:
    p = my_path / f
    cmd = compilation_command + [str(p)]
    if args.verbose:
        print(f"[INFO] running command: {' '.join(cmd)}")
    proc = subprocess.run(cmd, capture_output=True)
    Path(f).with_suffix(".o").unlink(missing_ok=True)
    if typ == "has__builtin_va_list":
        # Special case: compilation success determines presence or absence
        machdep["has__builtin_va_list"] = proc.returncode == 0
        continue
    if proc.returncode == 0:
        # all tests should fail on an appropriate _Static_assert
        # if compilation succeeds, we have a problem
        warnings.warn(f"WARNING: could not identify value of '{p.stem}', skipping")
        continue
    find_value(p.stem, typ, proc.stderr.decode())

version_output = subprocess.run(
    [args.compiler, args.compiler_version], capture_output=True, text=True
)
version = version_output.stdout.splitlines()[0]

machdep["compiler"] = args.compiler
machdep["cpp_arch_flags"] = args.cpp_arch_flags
machdep["version"] = version

missing_fields = [f for [f, v] in machdep.items() if v is None]

if missing_fields:
    print("WARNING: the following fields are missing from the machdep definition:")
    print(", ".join(missing_fields))

if args.check:
    check_machdep(machdep)

print_machdep(machdep)
