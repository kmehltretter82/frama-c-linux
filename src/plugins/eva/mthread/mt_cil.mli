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

open Cil_types

(** Function used to find the variables that should be declared in
    framac_mthread.h, with suitable error messages *)
val mthread_global_var: string -> unit -> varinfo

(** Is this statement a call to the primitive Frama_C_mthread_sync *)
val is_call_to_sync: stmt -> bool


(** Pretty-printing *)

val pretty_succs: Format.formatter -> stmt -> unit
(** Print the sid of the successors of a statement *)

val kinstr_to_source : kinstr -> Filepath.position option

(** Calls stacks, and related functions *)

type stack_elt = kernel_function * kinstr
module StackElt : Datatype.S with type t = stack_elt
type stack = stack_elt list

module Stack : sig
  include Datatype.S with type t = stack

  val pretty: Format.formatter -> t -> unit

  (** Stack call simulating an access to a shared variable at the given
      statement *)
  val access_to_var: stmt -> stack_elt

  (** Doess the given stack element represent an access to a shared variable *)
  val is_access_to_var: stack_elt -> bool

end
