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

val global_state: State.t ref
(** reference to the E-ACSL global state. Not defined here, yet required *) 

type t

val dummy: t
val empty: Visitor.frama_c_visitor -> t

val new_var:
  ?global:bool -> t -> term option -> typ -> 
  (varinfo -> exp (* the var as exp *) -> stmt list)
  -> exp * t
(** [new_var env t ty mk_stmts] extends [env] with a fresh variable of type
    [ty] corresponding to [t]. [global] indicates whether the new variable is
    global to the current function or local to the local block (default is
    [false], i.e. local).
    @return this variable as a C expression already initialized by applying it
    to [mk_stmts]. *)

val new_var_and_mpz_init:
  ?global:bool -> t -> term option -> 
  (varinfo -> exp (* the var as exp *) -> stmt list) 
  -> exp * t
(** Same as [new_var], but dedicated to mpz_t variables initialized by 
    {!Mpz.init}. *)

val add_assert: t -> stmt -> predicate named -> unit
(** [add_assert kf s p] extends the global environment with an assertion [p]
    associated to the statement [s] in function [kf]. *)

val add_stmt: t -> stmt -> t
  (** [add_stmt env s] extends [env] with the new statement [s] *)

val extend_stmt_in_place: t -> stmt -> pre:bool -> block -> t
(**  [extend_stmt_in_place env stmt ~pre b] modifies [stmt] in place in order to
     add the given [block]. If [pre] is [true], then this block is guaranteed
     to be at the first place of the resulting [stmt] whatever modification
     will be done by the visitor later. *)

val push: t -> t
(** Push a new local context in the environment *)

type where = Before | Middle | After
val pop_and_get: t -> stmt -> global_clear:bool -> where -> block * t
(* Pop the last local context and get back the corresponding new block
   containing the given [stmt] at the given place ([Before] is before the
   code corresponding to annotations, [After] is after this code and [Middle] is
   between the stmt corresponding to annotations and the ones for freeing the
   memory. *)

val pop: t -> t
(* Pop the last local context (ignore the corresponding new block if any *)

val get_generated_variables: t -> varinfo list
(** All the new variables local to the visited function. *)

val get_visitor: t -> Visitor.generic_frama_c_visitor

val stmt_of_label: t -> logic_label -> stmt

(*
Local Variables:
compile-command: "make"
End:
*)
