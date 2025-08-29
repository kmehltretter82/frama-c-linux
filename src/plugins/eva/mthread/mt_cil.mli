(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
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
