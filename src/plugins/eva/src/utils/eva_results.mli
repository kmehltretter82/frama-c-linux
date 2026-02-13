(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
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

[@@@ api_end]

val eval_tlval_as_location :
  ?result:Cil_types.varinfo ->
  Cvalue.Model.t ->  Cil_types.term -> Locations.location
