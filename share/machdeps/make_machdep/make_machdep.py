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
parser.add_argument("-o", type=argparse.FileType("w"), dest="dest_file")
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
parser.add_argument(
    "--check",
    action="store_true",
    help="checks that the generated machdep is conforming to the schema"
)
parser.add_argument(
    "--check-only",
    action="store_true",
    help="must be used in conjunction with --from-file to check that the provided input file is conforming to the schema"
)

args, other_args = parser.parse_known_args()

if not args.compiler_flags:
    args.compiler_flags = ["-c"]

def make_schema():
    schema_filename = my_path.parent / "machdep-schema.yaml"
    with open(schema_filename, "r") as schema:
        return yaml.safe_load(schema)


schema = make_schema()


def check_machdep(machdep):
    try:
        from jsonschema import validate, ValidationError

        validate(machdep, schema)
        return True
    except ImportError:
        warnings.warn("jsonschema is not available: no validation will be performed")
        return True
    except OSError:
        warnings.warn(f"error opening {schema_filename}: no validation will be performed")
        return True
    except ValidationError:
        warnings.warn("machdep object is not conforming to machdep schema")
        return False

if args.from_file:
    orig_file = open(args.from_file, "r")
    orig_machdep = yaml.safe_load(orig_file)
    orig_file.close()
    if args.check_only:
        if check_machdep(orig_machdep):
            exit(0)
        else:
            exit(1)
    if not "compiler" in orig_machdep or not "cpp_arch_flags" in orig_machdep:
        raise Exception("Missing fields in yaml file")
    args.compiler = orig_machdep["compiler"]
    if isinstance(orig_machdep["cpp_arch_flags"], list):
        args.cpp_arch_flags = orig_machdep["cpp_arch_flags"]
    else:  # old version of the schema used a single string
        args.cpp_arch_flags = orig_machdep["cpp_arch_flags"].split()

def print_machdep(machdep):
    if args.from_file and args.in_place:
        args.dest_file = open(args.from_file, "w")
    elif args.dest_file is None:
        args.dest_file = sys.stdout
    yaml.dump(machdep, args.dest_file, indent=4, sort_keys=True)

def make_machdep():
    machdep = {}
    for key in schema.keys():
        machdep[key] = None
    return machdep

machdep = make_machdep()

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
    ("ssize_t.c", "type"),
    ("wchar_t.c", "type"),
    ("ptrdiff_t.c", "type"),
    ("intptr_t.c", "type"),
    ("uintptr_t.c", "type"),
    ("int_fast8_t.c", "type"),
    ("int_fast16_t.c", "type"),
    ("int_fast32_t.c", "type"),
    ("int_fast64_t.c", "type"),
    ("uint_fast8_t.c", "type"),
    ("uint_fast16_t.c", "type"),
    ("uint_fast32_t.c", "type"),
    ("uint_fast64_t.c", "type"),
    ("wint_t.c", "type"),
    ("sig_atomic_t.c", "type"),
    ("time_t.c", "type"),
    ("char_is_unsigned.c", "bool"),
    ("little_endian.c", "bool"),
    ("has__builtin_va_list.c", "has__builtin_va_list"),
    ("weof.c", "macro"),
    ("wordsize.c", "macro"),
    ("posix_version.c", "macro"),
    ("limits_macros.c", "macro"),
    ("stdio_macros.c", "macro"),
    ("stdlib_macros.c", "macro"),
    ("nsig.c", "macro"),
    ("errno.c", "macrolist"),
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


def cleanup_cpp(output):
    lines = output.splitlines()
    macro = filter(lambda s: s != "" and s[0] != "#", lines)
    macro = map(lambda s: s.strip(), macro)
    return " ".join(macro)


def find_macros_value(output,is_list=False,entry=None):
    msg = re.compile("(\w+)_is = ([^;]+);")
    if is_list:
        assert(entry)
        machdep[entry] = {}
    for res in re.finditer(msg, output):
        name = res.group(1)
        value = res.group(2).strip()
        if is_list:
            machdep[entry][name] = value
        else:
            if name in machdep.keys():
                if args.verbose:
                    print(f"[INFO] setting {name} to {value}")
                machdep[name] = value
            else:
                warnings.warn(f"unexpected symbol '{name}', ignoring")
    if args.verbose:
        print(f"compiler output is:{output}")

for (f, typ) in source_files:
    p = my_path / f
    cmd = compilation_command + [str(p)]
    if typ == "macro" or typ == "macrolist":
        # We're just interested in expanding a macro,
        # treatment is a bit different than the rest.
        cmd = cmd + ["-E"]
    if args.verbose:
        print(f"[INFO] running command: {' '.join(cmd)}")
    proc = subprocess.run(cmd, capture_output=True)
    Path(f).with_suffix(".o").unlink(missing_ok=True)
    if typ == "macro":
        if proc.returncode != 0:
            warnings.warn(f"error in preprocessing value '{p}', some values won't be filled")
            if args.verbose:
                print(f"compiler output is:{proc.stderr.decode()}")
            name = p.stem
            if name in machdep:
                machdep[name] = ""
            continue
        find_macros_value(cleanup_cpp(proc.stdout.decode()))
        continue
    if typ == "macrolist":
        name = p.stem
        if proc.returncode != 0:
            warnings.warn(f"error in preprocessing value '{p}', some value might not be filled")
            if args.verbose:
                print(f"compiler output is:{proc.stderr.decode()}")
            if name in machdep:
                machdep[name] = {}
            continue
        find_macros_value(cleanup_cpp(proc.stdout.decode()),is_list=True,entry=name)
        continue
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
if args.from_file and args.in_place:
    machdep["machdep_name"] = Path(args.from_file).stem
elif args.dest_file:
    machdep["machdep_name"] = Path(args.dest_file.name).stem
else:
    machdep["machdep_name"] = "anonymous_machdep"

missing_fields = [f for [f, v] in machdep.items() if v is None]

if missing_fields:
    print("WARNING: the following fields are missing from the machdep definition:")
    print(", ".join(missing_fields))

print_machdep(machdep)
