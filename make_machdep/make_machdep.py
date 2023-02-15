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
Produces a machdep.ml file for a given architecture.

Prerequisites:

- A C11-compatible (cross-)compiler (with support for _Generic),
  or a (cross-)compiler having __builtin_types_compatible_p

- A (cross-)compiler supporting _Static_assert
- A (cross-)compiler supporting _Alignof or alignof

- objdump

This script tries to compile several source files into object files,
then uses objdump to extract information from the compilation.

We want to obtain values produced by the compiler.
In an ideal scenario, we are able to execute the binary, so we can just use
printf(). However, when cross-compiling, we may be unable to run the program.
Even worse, we may lack a proper runtime, and thus simply obtaining an
executable may be impossible.
However, we don't really need it: having an object file (with symbols) is
usually enough.

Compilation is split in several files because, for non-standard constructions,
some compilers (e.g. CompCert) may fail to parse them. We must detect these
cases and output warnings, but without preventing compilation of the rest.
"""

import argparse
import json
from pathlib import Path
import re
import subprocess
import sys
import warnings

parser = argparse.ArgumentParser(prog="make_machdep")
parser.add_argument("-v", "--verbose", action="store_true")
parser.add_argument("-o", default=sys.stdout, type=argparse.Filetype("w"), dest="dest_file")
parser.add_argument("--compiler")
parser.add_argument("--compiler-version")
parser.add_argument(
    "--cpp-arch-flags",
    nargs="+",
    default=[],
    help="architecture-specific flags needed for preprocessing, e.g. '-m32'",
)
parser.add_argument(
    "--compiler-flags",
    nargs="+",
    default=["-c"],
    help="flags to be given to the compiler (other than those set by --cpp-arch-flags); by default, '-c'",
)
parser.add_argument("--check", action="store_true")
args, other_args = parser.parse_known_args()


def print_machdep(machdep):
    json.dump(machdep, args.dest_file, indent=4, sort_keys=True)


fc_share = subprocess.run("frama-c-config -print-share-path", capture_output=True).output


def check_machdep(machdep):
    try:
        from jsonschema import validate, ValidationError

        with open(fc_share + "/machdeps/machdep-schema.json", "r") as schema:
            validate(machdep, json.load(schema))
    except ImportError:
        warnings.warn("jsonschema is not available: no validation will be performed")
    except OSError:
        warnings.warn("error opening machdep-schema.json: no validation will be performed")
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

compilation_command = other_args + args.compiler_flags

source_files = [
    ("sizeof_short.i", "number"),
    ("sizeof_int.i", "number"),
    ("sizeof_long.i", "number"),
    ("sizeof_longlong.i", "number"),
    ("sizeof_ptr.i", "number"),
    ("sizeof_float.i", "number"),
    ("sizeof_double.i", "number"),
    ("sizeof_longdouble.i", "number"),
    ("sizeof_void.i", "number"),
    ("sizeof_fun.i", "number"),
    ("sizeof_alignof_standard.c", "number"),
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

for (f, typ) in source_files:
    p = Path(f)
    cmd = compilation_command + [str(p)]
    if args.verbose:
        print(f"[INFO] running command: {' '.join(cmd)}")
    proc = subprocess.run(cmd, capture_output=True)
    if typ == "has__builtin_va_list":
        # Special case: compilation success determines presence or absence
        machdep["has__builtin_va_list"] = proc.returncode == 0
        continue
    if proc.returncode != 0:
        print(f"WARNING: error during compilation of '{p}', skipping")
        if args.verbose:
            print(proc.stderr.decode("utf-8"))
        continue
    objfile = p.with_suffix(".o")
    if not objfile.exists():
        print(f"WARNING: could not find expected '{objfile}', skipping")
        continue
    if typ == "const_string_literals":
        # Special case: try decoding different sections to find read-only object
        # Try ".rodata" section (ELF)
        symbols, _underscore_name = decode_object_file(objfile, section=".rodata")
        if ".rodata" in symbols and symbols[".rodata"] == 0x25:
            if args.verbose:
                print(f"[INFO] setting const_string_literals to true")
            machdep["const_string_literals"] = True
        else:
            # Try ".rdata" section (COFF)
            symbols, _underscore_name = decode_object_file(objfile, section=".rdata")
            if ".rdata" in symbols and symbols[".rdata"] == 0x25:
                if args.verbose:
                    print(f"[INFO] setting const_string_literals to true")
                machdep["const_string_literals"] = True
            else:
                symbols, _underscore_name = decode_object_file(objfile)
                if "const_string_literals" in symbols and symbols["const_string_literals"] == 0x25:
                    # Found symbol in .data section => not const
                    if args.verbose:
                        print(f"[INFO] setting const_string_literals to false")
                    machdep["const_string_literals"] = False
                else:
                    print(
                        f"WARNING: could not find const_string_literals in any of the expected sections, skipping"
                    )
        continue
    symbols, underscore_name = decode_object_file(objfile)
    if machdep["underscore_name"] is None:
        machdep["underscore_name"] = underscore_name
    if not symbols:
        print(f"WARNING: no symbols found in {objfile}")
        continue
    if typ == "number":
        for name, value in symbols.items():
            if name in machdep:
                if args.verbose:
                    print(f"[INFO] setting {name} to {value}")
                machdep[name] = value
            else:
                print(f"WARNING: unexpected symbol '{name}' in '{objfile}', ignoring")
                continue
    elif typ == "bool":
        for name, value in symbols.items():
            if name in machdep:
                if value == 0x15:
                    bvalue = True
                elif value == 0xF4:
                    bvalue = False
                else:
                    print(
                        f"WARNING: unexpected value '{value} for boolean '{name}' in '{objfile}', ignoring"
                    )
                    continue
                if args.verbose:
                    print(f"[INFO] setting {name} to {bvalue}")
                machdep[name] = bvalue
            else:
                print(f"WARNING: unexpected symbol '{name}' in '{objfile}', ignoring")
                continue
    elif typ == "type":
        for name, value in symbols.items():
            if not ("_IS_" in name):
                print(f"WARNING: unexpected symbol '{name}' in '{objfile}', ignoring")
                continue
            if value == 0xF4:
                # Symbol found with 'false' => incompatible type, ignore
                continue
            elif value != 0x15:
                print(
                    f"WARNING: unexpected value '{value}' for symbol '{name}' in '{objfile}', ignoring"
                )
                continue
            [name, original_type] = name.split("_IS_")
            original_type = original_type.replace("_", " ")
            if name in machdep:
                if args.verbose:
                    print(f"[INFO] setting {name} to {original_type}")
                machdep[name] = original_type
            else:
                print(
                    f"WARNING: unexpected symbol '{name}' (expected '{name}' in machdep) in '{objfile}', ignoring"
                )
                continue
    else:
        sys.exit(f"AssertionError: f {f} typ {typ}")

# Special fields

machdep["cpp_arch_flags"] = args.cpp_arch_flags

if args.compiler and args.compiler_version:
    machdep["compiler"] = args.compiler.lower()
    machdep["version"] = args.compiler_version
else:
    # Try to obtain version number from option '--version'
    compiler_version_command = compilation_command + ["--version"]
    proc = subprocess.run(compiler_version_command, capture_output=True)
    if proc.returncode != 0:
        print(
            f"WARNING: option '--version' unsupported by compiler; re-run this script with --compiler and --compiler-version"
        )
        if args.verbose:
            print(proc.stderr.decode("utf-8"))
    else:
        version_line = proc.stdout.decode("utf-8").split("\n")[0]
        if args.compiler:
            machdep["compiler"] = args.compiler.lower()
        else:
            if "gcc" in version_line.lower():
                machdep["compiler"] = "gcc"
            elif "clang" in version_line.lower():
                print(f"Note: clang is considered as a 'gcc'-type compiler for machdep purposes")
                machdep["compiler"] = "gcc"
            elif "msvc" in version_line.lower():
                machdep["compiler"] = "msvc"
            else:
                machdep["compiler"] = compilation_command[0]
        if args.compiler_version:
            machdep["version"] = args.compiler_version
        else:
            machdep["version"] = version_line

missing_fields = [f for [f, v] in machdep.items() if v is None]

if missing_fields:
    print("WARNING: the following fields are missing from the machdep definition:")
    print(", ".join(missing_fields))

print_machdep(machdep)
