#!/usr/bin/env python3
# -*- coding: utf-8 -*-
##########################################################################
#                                                                        #
#  SPDX-License-Identifier LGPL-2.1                                      #
#  Copyright (C) 2026 Frama-C Linux contributors                         #
#                                                                        #
##########################################################################

"""Create a one-entry compilation database for a kernel analysis harness.

The harness is compiled with the exact Kbuild command of an existing Linux
translation unit.  Its source directory is added to the include path so the
harness can include the original file by basename.  An optional source
override with the same basename supports historical replay without modifying
the checked-out Linux tree.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shlex
import sys
from typing import Any


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="map a Kbuild compilation command onto an analysis harness"
    )
    parser.add_argument(
        "-p", "--compilation-database", required=True, type=Path,
        help="input compile_commands.json",
    )
    parser.add_argument(
        "--source", required=True, type=Path,
        help="Linux translation unit whose Kbuild command should be reused",
    )
    parser.add_argument(
        "--harness", required=True, type=Path,
        help="analysis harness to compile",
    )
    parser.add_argument(
        "--source-override", type=Path,
        help="replacement source included by the harness; basename must match --source",
    )
    parser.add_argument("-o", "--output", required=True, type=Path)
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--quiet", action="store_true")
    return parser.parse_args()


def load_database(path: Path) -> list[dict[str, Any]]:
    try:
        with path.open(encoding="utf-8") as stream:
            value = json.load(stream)
    except OSError as exc:
        raise ValueError(f"cannot read '{path}': {exc}") from exc
    except json.JSONDecodeError as exc:
        raise ValueError(f"invalid JSON in '{path}': {exc}") from exc
    if not isinstance(value, list) or not all(isinstance(item, dict) for item in value):
        raise ValueError("compilation database must be an array of objects")
    return value


def entry_directory(entry: dict[str, Any], database_dir: Path) -> Path:
    directory = Path(entry.get("directory", database_dir))
    if not directory.is_absolute():
        directory = database_dir / directory
    return directory.resolve()


def resolve_entry_source(entry: dict[str, Any], database_dir: Path) -> Path:
    if not isinstance(entry.get("file"), str):
        raise ValueError("compilation database entry has no string 'file' member")
    source = Path(entry["file"])
    if not source.is_absolute():
        source = entry_directory(entry, database_dir) / source
    return source.resolve()


def command_arguments(entry: dict[str, Any]) -> list[str]:
    arguments = entry.get("arguments")
    if isinstance(arguments, list) and all(isinstance(item, str) for item in arguments):
        return list(arguments)
    command = entry.get("command")
    if isinstance(command, str):
        try:
            return shlex.split(command)
        except ValueError as exc:
            raise ValueError(f"cannot split compilation command: {exc}") from exc
    raise ValueError("matching compilation database entry has neither command nor arguments")


def resolves_to(token: str, directory: Path, source: Path) -> bool:
    if token.startswith("-"):
        return False
    candidate = Path(token)
    if not candidate.is_absolute():
        candidate = directory / candidate
    return candidate.resolve() == source


def write_database(path: Path, entry: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    try:
        with temporary.open("w", encoding="utf-8") as stream:
            json.dump([entry], stream, indent=2, ensure_ascii=False)
            stream.write("\n")
        os.replace(temporary, path)
    finally:
        try:
            temporary.unlink()
        except FileNotFoundError:
            pass


def main() -> int:
    args = parse_args()
    database = args.compilation_database.resolve()
    source = args.source.resolve()
    harness = args.harness.resolve()
    override = args.source_override.resolve() if args.source_override else None
    output = args.output.resolve()

    for label, path in (("compilation database", database), ("source", source),
                        ("harness", harness)):
        if not path.is_file():
            raise ValueError(f"{label} '{path}' does not exist")
    if override is not None:
        if not override.is_file():
            raise ValueError(f"source override '{override}' does not exist")
        if override.name != source.name:
            raise ValueError("--source-override basename must match --source")
    if output.exists() and not args.force:
        raise ValueError(f"output '{output}' already exists; use --force to replace it")

    entries = load_database(database)
    database_dir = database.parent
    matches = [
        entry for entry in entries
        if resolve_entry_source(entry, database_dir) == source
    ]
    if len(matches) != 1:
        raise ValueError(
            f"expected exactly one compilation entry for '{source}', found {len(matches)}"
        )

    original = matches[0]
    directory = entry_directory(original, database_dir)
    arguments = command_arguments(original)
    replaced = 0
    for index, token in enumerate(arguments):
        if resolves_to(token, directory, source):
            arguments[index] = str(harness)
            replaced += 1
    if replaced == 0:
        raise ValueError("source path was not present in the compilation command")

    include_directories = [override.parent] if override is not None else []
    include_directories.append(source.parent)
    arguments[1:1] = [f"-I{path}" for path in include_directories]

    mapped = dict(original)
    mapped.pop("command", None)
    mapped["arguments"] = arguments
    mapped["file"] = str(harness)
    write_database(output, mapped)

    if not args.quiet:
        print(f"harness database: {output}")
        print(f"source: {override or source}")
        print(f"harness: {harness}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except ValueError as exc:
        print(f"kernel-harness: {exc}", file=sys.stderr)
        sys.exit(2)
