#!/usr/bin/env python

"""
Produces a machdep.ml file for a given architecture.

Prerequisites:

- A C11-compatible (cross-)compiler (with support for _Generic),
  or a (cross-)compiler having __builtin_types_compatible_p

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
from pathlib import Path
import re
import subprocess
import sys

re_symbol_name = re.compile("^[0-9a-fA-F]+ <([^>]+)>: *$")

# Parsing objdump's format is not trivial: some versions print results as:
#   <offset>: 01 02 03 04           <assembly>
# That is, bytes separated by single spaces, then several spaces, then assembly;
# while other versions (e.g. for mips) print several bytes together:
#   <offset>: 01020304           <assembly>
# So we simply take all hexadecimal characters until the end of the line,
# and then split as soon as 2 consecutive spaces are found.
# Otherwise, we might end up considering instructions such as 'add' as part
# of the data.
# Unfortunately, objdump does not contain an option to display the data bytes
# themselves _without_ the disassembled data.
re_symbol_data = re.compile("^ *[0-9a-fA-F]+:[ \t]+([0-9a-fA-F ]+)")

parser = argparse.ArgumentParser(prog="make_machdep")
parser.add_argument("-v", "--verbose", action="store_true")
parser.add_argument("--compiler")
parser.add_argument("--compiler-version")
parser.add_argument("--cpp-arch-flags", nargs="+", default=[], help="architecture-specific flags needed for preprocessing, e.g. '-m32'")
parser.add_argument("--compiler-flags", nargs="+", default=["-c"], help="flags to be given to the compiler (other than those set by --cpp-arch-flags); by default, '-c'")
parser.add_argument("--objdump", action="store", help="objdump command to use", default="objdump")
args, other_args = parser.parse_known_args()

def print_machdep(machdep):
    print("open Cil_types")
    print("")
    print("let machdep : mach = {")
    for f, v in machdep.items():
        if isinstance(v, str):
            print(f"  {f} = \"{v}\";")
        elif isinstance(v, bool):
            print(f"  {f} = {'true' if v else 'false'};")
        elif isinstance(v, list):
            l = ", ".join([f'"{e}"' for e in v])
            print(f"  {f} = [{l}];")
        else:
            print(f"  {f} = {v};")

    print("}")

def decode_object_file(objfile, section=".data"):
    command = [args.objdump, "-j" + section, "-d", str(objfile)]
    if args.verbose:
        print(f"[INFO] running command: {' '.join(command)}")
    proc = subprocess.run(command, capture_output=True)
    if proc.returncode != 0:
        # Special case where objdump _may_ fail: section other than '.data'
        if section != ".data":
            return [], None
        print(f"error: command returned non-zero ({proc.returncode}): {' '.join(command)}")
        if args.verbose:
            print(proc.stderr.decode("utf-8"))
        sys.exit(1)
    symbols = {}
    cur_symbol = None
    underscore_name = None
    for line in proc.stdout.decode("utf-8").split("\n"):
        m = re_symbol_name.match(line)
        if m:
            #print(f"found symbol: [{m.group(1)}]")
            cur_symbol = m.group(1)
            continue
        m = re_symbol_data.match(line)
        if m:
            #print(f"found data: {m.group(1)}")
            if not cur_symbol:
                # This can happen when objdump decides to print more than one
                # line from the starting offset
                continue
                #sys.exit(f"error: found data without symbol")
            octet_string = m.group(1)
            if "  " in octet_string:
                [octet_string, _rest] = octet_string.split("  ", maxsplit=1)
            octet_string = octet_string.replace(" ", "")
            octets = []
            for i in range(0, len(octet_string) // 2):
                octets.append(int(octet_string[2*i:2*i+2], 16))
            # We assume all values fit in 1 byte (sizeof and alignof);
            # for the literal string, the first byte is enough.
            # We profit from having the symbol name to fill a special machdep field.
            underscore_name = cur_symbol.startswith("_")
            s = cur_symbol.strip("_") # Normalize symbol names
            symbols[s] = octets[0]
            cur_symbol = None
            continue
    return symbols, underscore_name

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
    "underscore_name": None,
    "const_string_literals": None,
    "little_endian": None,
    "alignof_aligned": None,
    "has__builtin_va_list": None,
    "compiler": None,
    "cpp_arch_flags": None,
    "version": None,
}

compilation_command = other_args + args.compiler_flags

source_files = [
    ("sizeof_alignof_standard.c", "number"),
    ("sizeof_void.c", "number"),
    ("sizeof_fun.c", "number"),
    ("sizeof_longdouble.c", "number"),
    ("alignof_longdouble.c", "number"),
    ("alignof_fun.c", "number"),
    ("alignof_str.c", "number"),
    ("alignof_aligned.c", "number"),
    ("size_t.c", "type"),
    ("wchar_t.c", "type"),
    ("ptrdiff_t.c", "type"),
    ("char_is_unsigned.c", "bool"),
    ("little_endian.c", "bool"),
    ("const_string_literals.c", "const_string_literals"),
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
                    print(f"WARNING: could not find const_string_literals in any of the expected sections, skipping")
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
                elif value == 0xf4:
                    bvalue = False
                else:
                    print(f"WARNING: unexpected value '{value} for boolean '{name}' in '{objfile}', ignoring")
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
            if value == 0xf4:
                # Symbol found with 'false' => incompatible type, ignore
                continue
            elif value != 0x15:
                print(f"WARNING: unexpected value '{value}' for symbol '{name}' in '{objfile}', ignoring")
                continue
            [name, original_type] = name.split("_IS_")
            original_type = original_type.replace("_", " ")
            if name in machdep:
                if args.verbose:
                    print(f"[INFO] setting {name} to {original_type}")
                machdep[name] = original_type
            else:
                print(f"WARNING: unexpected symbol '{name}' (expected '{name}' in machdep) in '{objfile}', ignoring")
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
        print(f"WARNING: option '--version' unsupported by compiler; re-run this script with --compiler and --compiler-version")
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
