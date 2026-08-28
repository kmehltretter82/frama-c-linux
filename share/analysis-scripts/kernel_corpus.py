#!/usr/bin/env python3
# -*- coding: utf-8 -*-
##########################################################################
#                                                                        #
#  SPDX-License-Identifier LGPL-2.1                                      #
#  Copyright (C) 2026 Frama-C Linux contributors                         #
#                                                                        #
##########################################################################

"""Measure Frama-C front-end compatibility on a C compilation database.

Each translation unit is parsed in a separate Frama-C process.  The script
keeps the complete output in per-file logs and writes a machine-readable JSON
report with a coarse failure stage, a more specific failure kind, timing,
warnings, and Metrics plug-in results when a typed AST is produced.
"""

from __future__ import annotations

import argparse
from collections import Counter, defaultdict
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from datetime import datetime, timezone
import fnmatch
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shlex
import shutil
import signal
import subprocess
import sys
import time
from typing import Any


SCHEMA_VERSION = 2
STAGES = (
    "typed",
    "database",
    "preprocessing",
    "syntax",
    "typing",
    "normalization",
    "missing-model",
    "analysis",
    "timeout",
    "internal-error",
    "unknown",
)


@dataclass(frozen=True)
class Target:
    index: int
    relative_path: str
    source: Path
    entry: dict[str, Any]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run Frama-C separately on a versioned compilation-database corpus."
    )
    parser.add_argument(
        "-p",
        "--compilation-database",
        required=True,
        type=Path,
        help="path to compile_commands.json",
    )
    parser.add_argument(
        "--kernel-root",
        required=True,
        type=Path,
        help="root of the Linux source tree",
    )
    parser.add_argument(
        "--corpus",
        type=Path,
        help="JSON manifest or newline-separated list of paths relative to --kernel-root",
    )
    parser.add_argument(
        "--include",
        action="append",
        default=[],
        metavar="GLOB",
        help="include matching relative paths; repeatable",
    )
    parser.add_argument(
        "--exclude",
        action="append",
        default=[],
        metavar="GLOB",
        help="exclude matching relative paths; repeatable",
    )
    parser.add_argument("--limit", type=int, help="run at most this many selected files")
    parser.add_argument(
        "--frama-c",
        help="Frama-C executable (defaults to FRAMAC_BIN/frama-c or PATH)",
    )
    parser.add_argument("--machdep", default="gcc_x86_64")
    parser.add_argument(
        "--frama-c-arg",
        action="append",
        default=[],
        metavar="ARG",
        help="extra Frama-C argument; use --frama-c-arg=-option for options",
    )
    parser.add_argument(
        "--model-header",
        action="append",
        default=[],
        type=Path,
        metavar="PATH",
        help="force-include a model header; repeatable",
    )
    parser.add_argument(
        "--no-manifest-models",
        action="store_true",
        help="ignore model_headers listed by a JSON corpus manifest",
    )
    parser.add_argument("--jobs", type=int, default=1)
    parser.add_argument("--timeout", type=float, default=120.0, metavar="SECONDS")
    parser.add_argument(
        "--no-metrics",
        action="store_true",
        help="do not run the Metrics plug-in on successfully parsed files",
    )
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        default=Path("kernel-corpus-results.json"),
    )
    parser.add_argument(
        "--log-dir",
        type=Path,
        help="per-file log directory (default: OUTPUT stem plus .logs)",
    )
    parser.add_argument(
        "--allow-kernel-mismatch",
        action="store_true",
        help="run even if the manifest's Linux commit differs from --kernel-root",
    )
    parser.add_argument("--force", action="store_true", help="overwrite an existing report")
    parser.add_argument("--quiet", action="store_true", help="suppress per-file progress")
    parser.add_argument(
        "--require-all-typed",
        action="store_true",
        help="exit nonzero when any selected translation unit is not typed",
    )
    args = parser.parse_args()
    if args.jobs < 1:
        parser.error("--jobs must be at least 1")
    if args.timeout <= 0:
        parser.error("--timeout must be greater than zero")
    if args.limit is not None and args.limit < 1:
        parser.error("--limit must be at least 1")
    return args


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_json(path: Path) -> Any:
    try:
        with path.open(encoding="utf-8") as stream:
            return json.load(stream)
    except OSError as exc:
        raise ValueError(f"cannot read '{path}': {exc}") from exc
    except json.JSONDecodeError as exc:
        raise ValueError(f"invalid JSON in '{path}': {exc}") from exc


def resolve_database_source(entry: dict[str, Any], database_dir: Path) -> Path:
    if "file" not in entry:
        raise ValueError("compilation database entry has no 'file' member")
    directory = Path(entry.get("directory", database_dir))
    if not directory.is_absolute():
        directory = database_dir / directory
    source = Path(entry["file"])
    if not source.is_absolute():
        source = directory / source
    return source.resolve()


def validate_relative_path(value: str) -> str:
    path = PurePosixPath(value)
    if path.is_absolute() or ".." in path.parts or not path.parts:
        raise ValueError(f"corpus path must be relative and stay below the kernel root: {value}")
    return path.as_posix()


def load_corpus(path: Path | None) -> tuple[dict[str, Any], list[str] | None]:
    if path is None:
        return {"name": "all-database-files-below-kernel-root"}, None
    if not path.is_file():
        raise ValueError(f"corpus manifest '{path}' does not exist")
    if path.suffix.lower() == ".json":
        value = load_json(path)
        if not isinstance(value, dict) or not isinstance(value.get("files"), list):
            raise ValueError("JSON corpus manifest must be an object containing a 'files' array")
        metadata = {key: item for key, item in value.items() if key != "files"}
        files = value["files"]
    else:
        metadata = {"name": path.stem}
        with path.open(encoding="utf-8") as stream:
            files = [line.strip() for line in stream if line.strip() and not line.lstrip().startswith("#")]
    if not all(isinstance(item, str) for item in files):
        raise ValueError("every corpus entry must be a string")
    normalized = [validate_relative_path(item) for item in files]
    if len(normalized) != len(set(normalized)):
        raise ValueError("corpus manifest contains duplicate paths")
    metadata["path"] = str(path.resolve())
    metadata["sha256"] = file_sha256(path)
    return metadata, normalized


def resolve_model_headers(
    manifest_path: Path | None,
    corpus: dict[str, Any],
    command_line_headers: list[Path],
    use_manifest_headers: bool,
) -> list[Path]:
    values: list[Path] = []
    if use_manifest_headers:
        manifest_headers = corpus.get("model_headers", [])
        if not isinstance(manifest_headers, list) or not all(
            isinstance(item, str) for item in manifest_headers
        ):
            raise ValueError("corpus model_headers must be an array of strings")
        if manifest_headers and manifest_path is None:
            raise ValueError("manifest model_headers require a corpus manifest path")
        assert manifest_path is not None or not manifest_headers
        manifest_dir = manifest_path.resolve().parent if manifest_path else Path.cwd()
        for item in manifest_headers:
            path = Path(item)
            values.append(path if path.is_absolute() else manifest_dir / path)
    values.extend(command_line_headers)

    headers: list[Path] = []
    seen: set[Path] = set()
    for value in values:
        path = value.resolve()
        if path in seen:
            continue
        if not path.is_file():
            raise ValueError(f"model header '{path}' does not exist")
        seen.add(path)
        headers.append(path)
    return headers


def model_header_argument(headers: list[Path]) -> str | None:
    if not headers:
        return None
    includes = " ".join(f"-include {shlex.quote(str(path))}" for path in headers)
    return f"-cpp-extra-args={includes}"


def git_metadata(root: Path) -> dict[str, Any]:
    def git(*arguments: str) -> str | None:
        try:
            completed = subprocess.run(
                ["git", "-C", str(root), *arguments],
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True,
                timeout=10,
            )
            return completed.stdout.strip()
        except (OSError, subprocess.SubprocessError):
            return None

    commit = git("rev-parse", "HEAD")
    description = git("describe", "--always", "--tags")
    status = git("status", "--porcelain")
    return {
        "commit": commit,
        "description": description,
        "dirty": bool(status) if status is not None else None,
    }


def find_frama_c(value: str | None) -> Path:
    if value:
        candidate = Path(value)
        if candidate.is_absolute() or candidate.parent != Path("."):
            executable = candidate.resolve()
        else:
            found = shutil.which(value)
            executable = Path(found) if found else candidate.resolve()
    elif os.getenv("FRAMAC_BIN"):
        executable = Path(os.environ["FRAMAC_BIN"]) / "frama-c"
    else:
        found = shutil.which("frama-c")
        if not found:
            raise ValueError("cannot find Frama-C; use --frama-c")
        executable = Path(found)
    if not executable.is_file() or not os.access(executable, os.X_OK):
        raise ValueError(f"Frama-C executable '{executable}' is not executable")
    return executable.resolve()


def command_version(executable: Path) -> str | None:
    try:
        completed = subprocess.run(
            [str(executable), "-version"],
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            timeout=15,
        )
        output = completed.stdout.strip()
        return output or None
    except (OSError, subprocess.SubprocessError):
        return None


def matches_filters(path: str, includes: list[str], excludes: list[str]) -> bool:
    included = not includes or any(fnmatch.fnmatch(path, pattern) for pattern in includes)
    excluded = any(fnmatch.fnmatch(path, pattern) for pattern in excludes)
    return included and not excluded


def select_paths(
    database: list[dict[str, Any]],
    database_dir: Path,
    kernel_root: Path,
    manifest_paths: list[str] | None,
    includes: list[str],
    excludes: list[str],
    limit: int | None,
) -> tuple[list[str], dict[Path, list[dict[str, Any]]]]:
    entries: dict[Path, list[dict[str, Any]]] = defaultdict(list)
    for entry in database:
        if not isinstance(entry, dict) or "file" not in entry:
            continue
        source = resolve_database_source(entry, database_dir)
        entries[source].append(entry)

    if manifest_paths is None:
        paths = []
        for source in entries:
            try:
                relative = source.relative_to(kernel_root).as_posix()
            except ValueError:
                continue
            paths.append(relative)
        paths.sort()
    else:
        paths = manifest_paths
    paths = [path for path in paths if matches_filters(path, includes, excludes)]
    if limit is not None:
        paths = paths[:limit]
    return paths, entries


ANSI_ESCAPE = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")


def diagnostic_excerpt(output: str) -> str | None:
    lines = ANSI_ESCAPE.sub("", output).splitlines()
    markers = (
        "User Error:",
        "Fatal error:",
        "Failure:",
        "syntax error",
        "Frama-C aborted",
        "internal error",
    )
    for index, line in enumerate(lines):
        if "Warning:" in line:
            continue
        if any(marker.lower() in line.lower() for marker in markers):
            excerpt = [line.strip()]
            for continuation in lines[index + 1 : index + 4]:
                if continuation.startswith("["):
                    break
                stripped = continuation.strip()
                if stripped:
                    excerpt.append(stripped)
            return " ".join(excerpt)[:1000]
    for line in reversed(lines):
        if line.strip():
            return line.strip()[:1000]
    return None


def classify_failure(return_code: int | None, timed_out: bool, output: str) -> tuple[str, str]:
    if timed_out:
        return "timeout", "process-timeout"
    if return_code == 0:
        return "typed", "typed-ast"
    if return_code is not None and return_code < 0:
        return "internal-error", f"signal:{-return_code}"

    lowered = output.lower()
    internal_markers = (
        "uncaught exception",
        "internal error",
        "please report as 'crash'",
        "frama-c crashed",
    )
    if any(marker in lowered for marker in internal_markers):
        return "internal-error", "frama-c-crash"

    # Prefer the first terminal diagnostic. A single translation unit can
    # produce several recoverable user errors before Frama-C exits; a later
    # error must not hide the construct that failed first.
    primary = (diagnostic_excerpt(output) or output).lower()

    def classify_text(text: str) -> tuple[str, str] | None:
        if "failed to evaluate constant expression in static assertion" in text:
            return "typing", "nonconstant-static-assert"
        if "static assertion failed" in text:
            return "typing", "failed-static-assert"
        if re.search(r"failed to (?:run|execute):", text) or any(
            marker in text
            for marker in ("preprocessing failed", "preprocessor call exited", "cannot preprocess")
        ):
            return "preprocessing", "preprocessor-command"
        if "syntax error" in text or "parse error" in text:
            return "syntax", "syntax-error"
        builtin = re.search(
            r"cannot resolve (?:variable|function)\s+(__builtin_[a-z0-9_]+)", text
        )
        if builtin:
            return "missing-model", f"builtin:{builtin.group(1)}"
        unsupported_builtin = re.search(
            r"(?:unsupported|unknown) builtin\s+(__builtin_[a-z0-9_]+)", text
        )
        if unsupported_builtin:
            return "missing-model", f"builtin:{unsupported_builtin.group(1)}"
        if "unable to compute offset" in text:
            return "normalization", "nonconstant-offset"
        if "normalization" in text:
            return "normalization", "normalization-failure"
        unresolved = re.search(r"cannot resolve variable\s+([a-z_$][a-z0-9_$]*)", text)
        if unresolved:
            return "typing", f"unresolved-variable:{unresolved.group(1)}"
        if "return statement with a value in function returning void" in text:
            return "typing", "return-type-mismatch"
        if "user error:" in text:
            return "typing", "typing-error"
        if re.search(r"\[(eva|wp|e-acsl|from|inout|scope)(?::|\])", text):
            return "analysis", "analysis-error"
        return None

    classification = classify_text(primary)
    if classification:
        return classification
    classification = classify_text(lowered)
    if classification:
        return classification
    return "unknown", "unclassified-nonzero-exit"


def parse_metrics(output: str) -> dict[str, int]:
    metrics: dict[str, int] = {}
    heading_names = {
        "Defined functions": "defined_functions",
        "Specified-only functions": "specified_only_functions",
        "Undefined and unspecified functions": "undefined_functions",
    }
    metric_names = {
        "Sloc": "sloc",
        "Decision point": "decision_points",
        "Global variables": "global_variables",
        "If": "if_statements",
        "Loop": "loops",
        "Goto": "gotos",
        "Assignment": "assignments",
        "Exit point": "exit_points",
        "Function": "functions",
        "Function call": "function_calls",
        "Pointer dereferencing": "pointer_dereferences",
        "Cyclomatic complexity": "cyclomatic_complexity",
    }
    for heading, key in heading_names.items():
        match = re.search(rf"^\[?metrics\]?\s*{re.escape(heading)}\s*\((\d+)\)", output, re.MULTILINE)
        if not match:
            match = re.search(rf"^\s*{re.escape(heading)}\s*\((\d+)\)", output, re.MULTILINE)
        if match:
            metrics[key] = int(match.group(1))
    for label, key in metric_names.items():
        match = re.search(rf"^\s*{re.escape(label)}\s*=\s*(\d+)\s*$", output, re.MULTILINE)
        if match:
            metrics[key] = int(match.group(1))
    return metrics


def output_facts(output: str) -> dict[str, Any]:
    warning_keys: Counter[str] = Counter()
    for line in output.splitlines():
        match = re.match(r"^\[([^]]+)\].*Warning:", line)
        if match:
            warning_keys[match.group(1)] += 1
    builtins = sorted(set(re.findall(r"Calling undeclared function\s+(__builtin_[A-Za-z0-9_]+)", output)))
    attributes = sorted(set(re.findall(r"Ignoring unknown attribute:\s+([A-Za-z0-9_]+)", output)))
    return {
        "warning_count": sum(warning_keys.values()),
        "warnings_by_key": dict(sorted(warning_keys.items())),
        "user_error_count": output.count("User Error:"),
        "undeclared_builtins": builtins,
        "unknown_attributes": attributes,
        "metrics": parse_metrics(output),
    }


def compile_command(entry: dict[str, Any]) -> list[str] | str | None:
    if isinstance(entry.get("arguments"), list):
        return entry["arguments"]
    if isinstance(entry.get("command"), str):
        return entry["command"]
    return None


def database_failure(index: int, path: str, source: Path, kind: str, detail: str) -> dict[str, Any]:
    return {
        "index": index,
        "file": path,
        "source": str(source),
        "stage": "database",
        "failure_kind": kind,
        "exit_code": None,
        "timed_out": False,
        "duration_seconds": 0.0,
        "first_diagnostic": detail,
        "frama_c_command": None,
        "compile_command": None,
        "compile_directory": None,
        "log": None,
        "warning_count": 0,
        "warnings_by_key": {},
        "user_error_count": 0,
        "undeclared_builtins": [],
        "unknown_attributes": [],
        "metrics": {},
    }


def terminate_process_group(process: subprocess.Popen[Any]) -> None:
    if process.poll() is not None:
        return
    try:
        if os.name == "posix":
            os.killpg(process.pid, signal.SIGTERM)
        else:
            process.terminate()
        process.wait(timeout=2)
    except (OSError, subprocess.TimeoutExpired):
        try:
            if os.name == "posix":
                os.killpg(process.pid, signal.SIGKILL)
            else:
                process.kill()
        except OSError:
            pass
        process.wait()


def run_target(
    target: Target,
    executable: Path,
    database: Path,
    machdep: str,
    extra_arguments: list[str],
    metrics: bool,
    timeout: float,
    kernel_root: Path,
    log_root: Path,
    output_parent: Path,
) -> dict[str, Any]:
    relative = PurePosixPath(target.relative_path)
    log_path = log_root.joinpath(*relative.parts).with_name(relative.name + ".log")
    log_path.parent.mkdir(parents=True, exist_ok=True)
    command = [
        str(executable),
        "-machdep",
        machdep,
        "-compilation-db",
        str(database),
    ]
    if metrics:
        command.append("-metrics")
    command.extend(extra_arguments)
    command.append(str(target.source))

    started = time.monotonic()
    timed_out = False
    return_code: int | None = None
    with log_path.open("w", encoding="utf-8", errors="replace") as log:
        try:
            process = subprocess.Popen(
                command,
                cwd=kernel_root,
                stdout=log,
                stderr=subprocess.STDOUT,
                text=True,
                start_new_session=os.name == "posix",
            )
            try:
                return_code = process.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                timed_out = True
                terminate_process_group(process)
                return_code = process.returncode
        except OSError as exc:
            log.write(f"runner: could not start Frama-C: {exc}\n")
    duration = time.monotonic() - started
    output = log_path.read_text(encoding="utf-8", errors="replace")
    stage, kind = classify_failure(return_code, timed_out, output)
    facts = output_facts(output)
    try:
        log_reference = os.path.relpath(log_path, output_parent)
    except ValueError:
        log_reference = str(log_path)
    result = {
        "index": target.index,
        "file": target.relative_path,
        "source": str(target.source),
        "stage": stage,
        "failure_kind": kind,
        "exit_code": return_code,
        "timed_out": timed_out,
        "duration_seconds": round(duration, 3),
        "first_diagnostic": diagnostic_excerpt(output),
        "frama_c_command": command,
        "compile_command": compile_command(target.entry),
        "compile_directory": target.entry.get("directory"),
        "log": log_reference,
        **facts,
    }
    return result


def write_report(path: Path, report: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    try:
        with temporary.open("w", encoding="utf-8") as stream:
            json.dump(report, stream, indent=2, ensure_ascii=False)
            stream.write("\n")
        os.replace(temporary, path)
    finally:
        try:
            temporary.unlink()
        except FileNotFoundError:
            pass


def summary_for(results: list[dict[str, Any]]) -> dict[str, Any]:
    by_stage = Counter(result["stage"] for result in results)
    by_kind = Counter(result["failure_kind"] for result in results if result["stage"] != "typed")
    typed = by_stage["typed"]
    total = len(results)
    return {
        "attempted": total,
        "typed": typed,
        "success_rate": round(typed / total, 6) if total else 0.0,
        "by_stage": {stage: by_stage[stage] for stage in STAGES if by_stage[stage]},
        "failures_by_kind": dict(sorted(by_kind.items())),
        "total_process_seconds": round(sum(result["duration_seconds"] for result in results), 3),
    }


def main() -> int:
    args = parse_args()
    database_path = args.compilation_database.resolve()
    kernel_root = args.kernel_root.resolve()
    output_path = args.output.resolve()
    if output_path.exists() and not args.force:
        sys.exit(f"error: report '{output_path}' already exists; use --force to overwrite it")
    if not database_path.is_file():
        sys.exit(f"error: compilation database '{database_path}' does not exist")
    if not kernel_root.is_dir():
        sys.exit(f"error: kernel root '{kernel_root}' does not exist")

    try:
        database = load_json(database_path)
        if not isinstance(database, list):
            raise ValueError("compilation database root must be an array")
        manifest_path = args.corpus.resolve() if args.corpus else None
        corpus, manifest_paths = load_corpus(manifest_path)
        executable = find_frama_c(args.frama_c)
        model_headers = resolve_model_headers(
            manifest_path,
            corpus,
            args.model_header,
            not args.no_manifest_models,
        )
        extra_arguments = list(args.frama_c_arg)
        model_argument = model_header_argument(model_headers)
        if model_argument:
            extra_arguments.append(model_argument)
        kernel = git_metadata(kernel_root)
        declared_commit = corpus.get("linux_commit")
        if (
            declared_commit
            and kernel["commit"] != declared_commit
            and not args.allow_kernel_mismatch
        ):
            raise ValueError(
                f"corpus requires Linux {declared_commit}, but --kernel-root is "
                f"{kernel['commit']}; use --allow-kernel-mismatch to override"
            )
        selected, entries = select_paths(
            database,
            database_path.parent,
            kernel_root,
            manifest_paths,
            args.include,
            args.exclude,
            args.limit,
        )
    except ValueError as exc:
        sys.exit(f"error: {exc}")

    if not selected:
        sys.exit("error: no translation units selected")

    log_root = (
        args.log_dir.resolve()
        if args.log_dir
        else output_path.with_suffix("").with_name(output_path.stem + ".logs")
    )
    log_root.mkdir(parents=True, exist_ok=True)
    immediate: list[dict[str, Any]] = []
    targets: list[Target] = []
    for index, relative_path in enumerate(selected):
        source = (kernel_root / PurePosixPath(relative_path)).resolve()
        if not source.is_relative_to(kernel_root):
            immediate.append(
                database_failure(index, relative_path, source, "path-escape", "source escapes kernel root")
            )
        elif not source.is_file():
            immediate.append(
                database_failure(index, relative_path, source, "missing-source", "source file does not exist")
            )
        elif source not in entries:
            immediate.append(
                database_failure(
                    index,
                    relative_path,
                    source,
                    "missing-command",
                    "source has no compilation-database entry",
                )
            )
        elif len(entries[source]) != 1:
            immediate.append(
                database_failure(
                    index,
                    relative_path,
                    source,
                    "ambiguous-command",
                    f"source has {len(entries[source])} compilation-database entries",
                )
            )
        else:
            targets.append(Target(index, relative_path, source, entries[source][0]))

    completed_results: list[dict[str, Any]] = []
    with ThreadPoolExecutor(max_workers=args.jobs) as executor:
        futures = {
            executor.submit(
                run_target,
                target,
                executable,
                database_path,
                args.machdep,
                extra_arguments,
                not args.no_metrics,
                args.timeout,
                kernel_root,
                log_root,
                output_path.parent,
            ): target
            for target in targets
        }
        finished = 0
        for future in as_completed(futures):
            result = future.result()
            completed_results.append(result)
            finished += 1
            if not args.quiet:
                print(
                    f"[{finished}/{len(targets)}] {result['stage']:<15} "
                    f"{result['duration_seconds']:>8.3f}s  {result['file']}",
                    flush=True,
                )

    results = sorted(immediate + completed_results, key=lambda item: item["index"])
    summary = summary_for(results)
    report = {
        "schema_version": SCHEMA_VERSION,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "frama_c": {
            "executable": str(executable),
            "version": command_version(executable),
            "machdep": args.machdep,
            "extra_arguments": extra_arguments,
            "model_headers": [
                {"path": str(path), "sha256": file_sha256(path)}
                for path in model_headers
            ],
            "metrics_enabled": not args.no_metrics,
        },
        "kernel": {"root": str(kernel_root), **kernel},
        "compilation_database": {
            "path": str(database_path),
            "sha256": file_sha256(database_path),
            "entries": len(database),
        },
        "corpus": corpus,
        "configuration": {
            "jobs": args.jobs,
            "timeout_seconds": args.timeout,
            "include": args.include,
            "exclude": args.exclude,
            "limit": args.limit,
            "manifest_models_enabled": not args.no_manifest_models,
        },
        "summary": summary,
        "results": results,
    }
    write_report(output_path, report)

    stages = ", ".join(f"{name}={count}" for name, count in summary["by_stage"].items())
    print(
        f"typed {summary['typed']}/{summary['attempted']} "
        f"({summary['success_rate'] * 100:.1f}%); {stages}"
    )
    print(f"report: {output_path}")
    if args.require_all_typed and summary["typed"] != summary["attempted"]:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
