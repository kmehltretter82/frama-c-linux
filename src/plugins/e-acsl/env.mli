(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2010                                               *)
(*    CEA (Commissariat à l'Énergie Atomique)                             *)
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

(** Environments. 

    Environments handle all the new C constructs (variables, statements and
    annotations. *) 

val self: State.t ref

type t

val empty: t

val new_var: 
  t -> typ -> (varinfo -> exp (* the var as exp *) -> stmt list) -> exp * t
  (** [new_var env ty mk_stmts] extends [env] with a fresh variable of type
      [ty]. 
      @return this variable as a C expression already initialized by applying it
      to [mk_stmts]. *)

val new_var_and_mpz_init:
  t -> (varinfo -> exp (* the var as exp *) -> stmt list) -> exp * t
  (** Same as [new_var], but dedicated to mpz_t variables initialized by 
     {!Mpz.init}. *)

val no_overlap: from:t -> t -> t
  (** [no_overlap ~from env] returns env, but ensures that new generated
     variables will not overlap with those of [from]. *)
  
val merge_function_vars: from:t -> t -> t
(** [merge_function_vars ~from env] copies the generated variables local to the
    visited function of [from] to [env]. Assume that there is no overlaping
    between [from] and [env]. *)

val merge_block_vars: from:t -> t -> t
(** Like [merge_function_vars] for generated variables local to the built
    block. *)

val add_stmt: t -> stmt -> t
  (** [add_stmt env s] extends [env] with the new statement [s] *)

val add_assert: kernel_function -> stmt -> predicate named -> unit
  (** [add_assert kf s p] extends the global environment with an assertion [p]
      associated to the statement [s] in function [kf]. *)

val register_actions_queue: (unit -> unit) Queue.t -> unit
  (** To be called once at initialization time: the queue of event of the
      visitor required for generating annotations. *)

val generated_function_variables: t -> varinfo list
(** All the new variables local to the visited function. *)

val generated_block_variables: t -> varinfo list
(** All the new variables local to the block being built. *)

val block: t -> stmt -> block
  (** [block env s] returns the block of statements including [s] and the new
     constructs of [env]. *)

val block_as_stmt: t -> stmt -> stmt
(** Like [block], but generate the block as a stmt *)

val block_option: t -> stmt -> block option
  (** [block_option env s] returns the block of statements including [s] and the
      new constructs of [env], if any. *)

val close_block_option: t -> block option
  (** like [block_option] but includes no additional statement: only include the
      new constructs of [env], if any. *)

val is_empty: t -> bool
  (** Is the given environment empty? *)

val is_empty_block: t -> bool
  (** Does the given environment not contain new statements? *)

val pretty: Format.formatter -> t -> unit
(** Debugging purpose *)

(*
Local Variables:
compile-command: "make"
End:
*)
