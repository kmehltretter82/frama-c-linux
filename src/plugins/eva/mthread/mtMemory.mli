(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2025                                               *)
(*    CEA (Commissariat à l'énergie atomique et aux énergies              *)
(*         alternatives)                                                  *)
(*                                                                        *)
(*  All rights reserved.                                                  *)
(*  Contact CEA LIST for licensing.                                       *)
(*                                                                        *)
(**************************************************************************)

open Cil_types


module Types : sig

  (** Pointers are the adress of a variable, with a potential offset,
      and are used to refer in a simple way to an adress in memory *)
  type pointer = Cil_types.varinfo * int

  module Pointer: Datatype.S_with_collections with type t = pointer

  type state = Cvalue.Model.t
  type value = Cvalue.V.t
  type zone = Locations.Zone.t
  type slice = Cvalue.V_Offsetmap.t

  type functions_states = state Cil_datatype.Stmt.Hashtbl.t
  type map_functions_states = state Cil_datatype.Stmt.Map.t

  type state_accesser =
    | Global
    | Local of functions_states

  val map_functions_states_to_get_state: map_functions_states -> (stmt -> state)

  val iter_requests:
    state_accesser -> stmt -> (Eva.Results.request -> unit) -> unit

  val merge_map_non_map_functions_states:
    map_functions_states -> functions_states -> map_functions_states
  val merge_map_functions_states:
    map_functions_states -> map_functions_states -> map_functions_states

end
open Types


(** {1 Union of state, values and list of values} *)

(**. We also return a boolean indicating whether an update has taken
   place, ie. if the result of the union is different (thus greater)
   from the first argument. Notice that this means that those
   functions are not symmetrical! *)
val join_state : state -> state -> state * bool
val join_value : value -> value -> value * bool

val join_params : value list -> value list -> value list * bool

val join_zone : zone -> zone -> zone * bool

(** Remove all the values that are not global variables from the state *)
val clear_non_globals : state -> state

(** {1 Functions dealing with frama-c special variables} *)
val is_frama_c_var : varinfo -> bool
val is_frama_c_base : Base.t -> bool
val remove_frama_c_var_from_zone : zone -> zone
val remove_frama_c_var_from_mem : state -> state


(** {1 Reading and writing in memory} *)

(** [read_slice ~p ~sbytes st] reads [sbytes] starting
    from [p] in [state]. *)
val read_slice: p:value -> sbytes:int -> state -> slice

(** Return the value pointed by the given int pointer *)
val read_int_pointer: pointer -> state -> value


(** [write_int_pointer p v state] write the int [v] at the location
    pointed [p] in state [state]. *)
val write_int_pointer : pointer -> int -> state -> state

(** [replace_value_at_int_pointer p ~before ~after state] replaces [before]
    by [after] in the abstract value bound at location [p] in [state]. *)
val replace_value_at_int_pointer:
  pointer -> before:int -> after:int -> state -> state

(** [write_at_pointer ~p ~sbytes ~slice st] alters [state] by
    writing at the [sbytes] bytes starting at [p] the slice [v]. *)
val write_slice:
  p:pointer -> sbytes:int -> slice:slice -> exact:bool -> state -> state


val lval_from_pointer: pointer -> lval


(** {1 Conversion to and from Mthread world to the value analysis} *)

val extract_fun : value -> kernel_function MtLib.conversion
val extract_pointer : value -> pointer MtLib.conversion
val extract_int : value -> int MtLib.conversion
val extract_int_possibly_zero :
  value -> (int * [`Exact | `WithZero]) MtLib.conversion
val extract_constant_string : value -> string MtLib.conversion
val extract_non_wide_string : Base.cstring -> string MtLib.conversion


val int_to_value: int -> value

val pretty_slice: slice Pretty_utils.formatter
