(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2024                                               *)
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

open Cil_types

val is_non_terminating_instr: stmt -> bool
(** Returns [true] iff there exists executions of the statement that does
    not always fail/loop (for function calls). Must be called *only* on
    statements that are instructions. *)

(** Returns the initial state provided by [set_initial_state] below, if any. *)
val get_initial_state: unit -> Cvalue.Model.t option

(** Returns the values of the main arguments provided by [set_main_args] below,
    if any. *)
val get_main_args: unit -> Cvalue.V.t list option

[@@@ api_start]

(** Internal temporary API: please do not use it, as it should be removed in a
    future version. *)

(** {2 Initial cvalue state} *)

(** Specifies the initial cvalue state to use. *)
val set_initial_state: Cvalue.Model.t -> unit

(** Ignores previous calls to [set_initial_state] above, and uses the default
    initial state instead. *)
val use_default_initial_state: unit -> unit

(** Specifies the values of the main function arguments. Beware that the
    analysis fails if the number of given values is different from the number
    of arguments of the entry point of the analysis. *)
val set_main_args: Cvalue.V.t list -> unit

(** Ignores previous calls to [set_main_args] above, and uses the default
    main argument values instead. *)
val use_default_main_args: unit -> unit

(** {2 Results} *)

type results

val get_results: unit -> results
val set_results: results -> unit
val merge: results -> results -> results

(** Change the callstacks for the results for which this is meaningful.
    For technical reasons, the top of the callstack must currently
    be preserved. *)
val change_callstacks:
  (Callstack.t -> Callstack.t) -> results -> results

val eval_tlval_as_location :
  ?result:Cil_types.varinfo ->
  Cvalue.Model.t ->  Cil_types.term -> Locations.location

[@@@ api_end]

(*
Local Variables:
compile-command: "make -C ../../../.."
End:
*)
