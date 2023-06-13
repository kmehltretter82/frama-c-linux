(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2023                                               *)
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

(** This module is here for compatibility reasons only and will be removed in
    future versions. Use [Eva.Callstack] instead *)

module Callstack :
sig
  type call = Cil_types.kernel_function * Cil_types.stmt

  module Call : Datatype.S with type t = call

  type local_stack = private {
    thread: int;
    entry_point: Cil_types.kernel_function;
    stack: call list;
  }

  type callstack = private
    | Global of Cil_types.varinfo
    | Local of local_stack

  include Datatype.S_with_collections with type t = callstack

  val compare_lex : t -> t -> int

  val init_global : Cil_types.varinfo -> t
  val init_local : ?thread:int -> Cil_types.kernel_function -> t

  val is_local : t -> bool

  val push : Cil_types.kernel_function -> Cil_types.stmt -> t -> t
  val pop : t -> (Cil_types.kernel_function * Cil_types.stmt * t) option
  val top : t -> (Cil_types.kernel_function * Cil_types.stmt) option
  val top_kf : t -> Cil_types.kernel_function
  val top_callsite : t -> Cil_types.stmt option
  val top_call : t -> Cil_types.kernel_function * Cil_types.kinstr

  val to_legacy : t -> Value_types.callstack
  val to_kf_list : t -> Cil_types.kernel_function list
  val to_stmt_list : t -> Cil_types.stmt list
end
[@@alert db_deprecated
    "Eva_types is only provided for compatibility reason and will be removed \
     in a future version of Frama-C. Please use the Eva.Callstack in the \
     public API instead."]
