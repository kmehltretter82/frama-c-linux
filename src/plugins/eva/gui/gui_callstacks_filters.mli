(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** Filtering on analysis callstacks *)

(** List.rev on a callstack, enforced by strong typing outside of this module *)
type rcallstack

val empty: rcallstack
val from_callstack: Callstack.t -> rcallstack


(** Filters on callstacks. [None] means that all callstacks are active *)
type filter = rcallstack list option

val callstack_matches: filter -> rcallstack -> bool
val callsite_matches: filter -> Cil_types.stmt -> bool

(* Callstacks currently being focused. *)
val focused_callstacks: unit -> filter

(* Focuses on the given callstacks. *)
val focus_on_callstacks: filter -> unit

val is_reachable_stmt: filter -> Cil_types.stmt -> bool
val is_non_terminating_instr: filter -> Cil_types.stmt -> bool

(* This function must be called each time a new Gui_eval.S is built over the
   abstractions used for an Eva analysis. It registers the two functions
   [lval_to_zone_gui] and [tlval_to_zone_gui], that depend on the abstractions
   used by the analysis and on the focused callstacks. *)
val register_to_zone_functions : (module Gui_eval.S) -> unit
