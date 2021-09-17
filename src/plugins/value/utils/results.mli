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

(* Usage sketch :

   Eva.Results.(before stmt |> in_callstack cs |> eval_var vi |> as_int)

   or, if you prefer

   Eva.Results.(as_int (eval_var vi (in_callstack cs (before stmt))))
*)

type callstack = (Cil_types.kernel_function * Cil_types.kinstr) list
type 'a by_callstack = (callstack*'a) list

type request
type evaluation
type lvaluation

type error = Bottom | Top | DisabledDomain
type 'a result = ('a,error) Result.t

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

(* State requests *)
val callstacks : request -> callstack list
val equality_class : Cil_types.exp -> request -> Cil_types.exp list result
val as_cvalue_model : request -> Cvalue.Model.t result

(* Evaluation *)
val eval_var : Cil_types.varinfo -> request -> evaluation
val eval_lval : Cil_types.lval -> request -> evaluation
val eval_exp : Cil_types.exp -> request -> evaluation

val eval_address : Cil_types.lval -> request -> lvaluation

(* Value conversion *)
val as_int : evaluation -> int result
val as_integer : evaluation -> Integer.t result
val as_float : evaluation -> float result
val as_functions : evaluation -> Cil_types.kernel_function list result
val as_ival : evaluation -> Ival.t result
val as_fval : evaluation -> Fval.t result
val as_cvalue : evaluation -> Cvalue.V.t result

val as_location : lvaluation -> Locations.location result
val as_zone : lvaluation -> Locations.Zone.t result

(* Evaluation properties *)
val is_initialized : evaluation -> bool
val deps : evaluation -> Locations.Zone.t
val alarms : evaluation -> Alarms.t list

(* Bottomness *)
val is_bottom : evaluation -> bool
val is_called : Cil_types.kernel_function -> bool
val is_reachable : Cil_types.stmt -> bool
