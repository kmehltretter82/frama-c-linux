(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2025                                               *)
(*    CEA (Commissariat à l'énergie atomique et aux énergies              *)
(*         alternatives)                                                  *)
(*                                                                        *)
(*  you can redistribute it and/or modify it under the terms of the GNU   *)
(*  Lesser General Public License as published by the Free Software       *)
(*  Foundation, version 2.1.                                              *)
(*                                                                        *)
(*  It is distributed in the hope that it will be useful,                 *)
(*  but WITHOUT ANY WARRANTY; without even the implied warranty of        *)
(*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *)
(*  GNU Lesser General Public License for more details.                   *)
(*                                                                        *)
(*  See the GNU Lesser General Public License version 2.1                 *)
(*  for more details (enclosed in the file licenses/LGPLv2.1).            *)
(*                                                                        *)
(**************************************************************************)

module MThread: Plugin.S

include Log.Messages
val debug_level: unit -> int

(** behavior of option -mthread. *)
module Enabled: Parameter_sig.Bool

(** behavior of option -mt-keep-analyses. Three
    possible values: all, last or none. *)
module KeepProjects: Parameter_sig.String

(** behavior of option -mt-projects-on-disk *)
module ToDisk: Parameter_sig.Bool

(** behavior of option -mt-projects-on-disk-prefix. *)
module ToDiskPrefix: Parameter_sig.String

(** behavior of option -mt-ignore-null. *)
module IgnoreNull: Parameter_sig.Bool

(** behavior of option -mt-write-races. *)
module WriteWriteRaces: Parameter_sig.Bool

(** behavior of option -mt-shared-values. From 0 to 2. *)
module DumpSharedVarsValues: Parameter_sig.Int

(** behavior of option -mt-shared-accesses-synchronization. *)
module CheckProtections: Parameter_sig.Bool

(** behavior of option -mt-moderate-warning. *)
module ModerateWarnings: Parameter_sig.Bool

(** behavior of option -mt-nice-offsets. *)
module NiceOffsets: Parameter_sig.Bool

(** behavior of option -mt-print-callstacks. *)
module PrintCallstacks: Parameter_sig.Bool

(** behavior of option -mt-show-sids. *)
module ShowSid: Parameter_sig.Bool

(** behavior of option -mt-time. *)
module ShowTime: Parameter_sig.Bool

(** behavior of option -mt-skip-threads. *)
module SkipThreads: Parameter_sig.String_set

(** behavior of option -mt-only-threads. *)
module OnlyThreads: Parameter_sig.String_set

(** behavior of option -mt-stop-after. *)
module StopAfter: Parameter_sig.Int

(** behavior of option -mt-keep-dot. *)
module KeepDotFiles: Parameter_sig.Bool

(** behavior of option -mt-concat-dot-files-to. *)
module ConcatDotFilesTo: Parameter_sig.Filepath

(** behavior of option -mt-extract. *)
module ExtractModels: Parameter_sig.String_set

(** behavior of option -mt-full-cfg. *)
module FullCfg: Parameter_sig.Bool

(** behavior of option -mt-non-shared-accesses. *)
module KeepWhiteNodes: Parameter_sig.Bool

(** behavior of option -mt-non-concurrent-accesses. *)
module KeepGreenNodes: Parameter_sig.Bool

(** behavior of option -mt-return-edges. *)
module ShowReturnEdges: Parameter_sig.Bool

(** behavior of option -mt-inline-callbacks. *)
module PopTopFunctionForCallbacks: Parameter_sig.Bool

(** behavior of option -mt-compact. *)
module CompactFunctions: Parameter_sig.String_set
