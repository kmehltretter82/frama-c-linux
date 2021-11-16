(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2021                                               *)
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

[@@@ api_start]
(* Usage sketch :

   Eva.Results.(before stmt |> in_callstack cs |> eval_var vi |> as_int)

   or, if you prefer

   Eva.Results.(as_int (eval_var vi (in_callstack cs (before stmt))))
*)

type callstack = (Cil_types.kernel_function * Cil_types.kinstr) list

type request

type value
type address
type 'a evaluation

type error = Bottom | Top | DisabledDomain
type 'a result = ('a,error) Result.t

val string_of_error : error -> string
val pretty_error : Format.formatter -> error -> unit
val pretty_result : (Format.formatter -> 'a -> unit) ->
  Format.formatter -> 'a result -> unit

(* Control point selection *)
val at_start : request
val at_end : request
val at_start_of : Cil_types.kernel_function -> request
val at_end_of : Cil_types.kernel_function -> request
val before : Cil_types.stmt -> request
val after : Cil_types.stmt -> request
val before_kinstr : Cil_types.kinstr -> request
val after_kinstr : Cil_types.kinstr -> request

(* Callstack selection *)
val in_callstack : callstack -> request -> request
val in_callstacks : callstack list -> request -> request
val filter_callstack : (callstack -> bool) -> request -> request

(* Working with callstacks *)
val callstacks : request -> callstack list
val by_callstack : request -> (callstack * request) list
val iter_callstacks : (callstack -> request -> unit) -> request -> unit
val fold_callstacks : (callstack -> request -> 'a -> 'a) -> 'a -> request -> 'a

(* State requests *)
val equality_class : Cil_types.exp -> request -> Cil_types.exp list result
val as_cvalue_model : request -> Cvalue.Model.t result

(* Dependencies *)
val expr_deps : Cil_types.exp -> request -> Locations.Zone.t
val lval_deps : Cil_types.lval -> request -> Locations.Zone.t

(* Evaluation *)
val eval_var : Cil_types.varinfo -> request -> value evaluation
val eval_lval : Cil_types.lval -> request -> value evaluation
val eval_exp : Cil_types.exp -> request -> value evaluation

val eval_address : Cil_types.lval -> request -> address evaluation

val eval_callee : Cil_types.exp -> request -> Cil_types.kernel_function list result (* Ignores non-function values; exp must come from Cil Call constructor and are restricted to lvalues with no offset *)

(* Value conversion *)
val as_int : value evaluation -> int result
val as_integer : value evaluation -> Integer.t result
val as_float : value evaluation -> float result
val as_ival : value evaluation -> Ival.t result
val as_fval : value evaluation -> Fval.t result
val as_cvalue : value evaluation -> Cvalue.V.t result

val as_location : address evaluation -> Locations.location result
val as_zone : address evaluation -> Locations.Zone.t result

(* Evaluation properties *)
val is_initialized : value evaluation -> bool
val alarms : 'a evaluation -> Alarms.t list

(* Reachability *)
val is_empty : request -> bool
val is_bottom : 'a evaluation -> bool
val is_called : Cil_types.kernel_function -> bool (* called during the analysis, not by the actual program *)
val is_reachable : Cil_types.stmt -> bool (* reachable by the analysis, not by the actual program *)

(* Callers / callsites *)
val callers : Cil_types.kernel_function -> Cil_types.kernel_function list
val callsites : Cil_types.kernel_function -> Cil_types.stmt list
val callsites_per_caller : Cil_types.kernel_function ->
    (Cil_types.kernel_function * Cil_types.stmt list) list
[@@@ api_end]
