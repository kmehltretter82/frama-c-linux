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

(** {2 Callstacks related types and functions} *)

(** Prints the current callstack. *)
val pp_callstack : Format.formatter -> unit

(** {2 Others} *)

(* TODO: Document the rest of this file. *)
val emitter : Emitter.t
val get_slevel : Kernel_function.t -> Parameters.SlevelFunction.value
val get_subdivision: stmt -> int
val pretty_actuals :
  Format.formatter -> (Eva_ast.exp * Cvalue.V.t) list -> unit

(** [protect f ~cleanup] runs [f]. On a user interruption or a Frama-C error,
    if option -save is set, applies [cleanup]. This is used to clean up and
    save partial results when the analysis is aborted. *)
val protect: (unit -> 'a) -> cleanup:(unit -> unit) -> 'a

(* Statements for which the analysis has degenerated. [true] means that this is
   the statement on which the degeneration occurred, or a statement above in
   the callstack *)
module DegenerationPoints:
  State_builder.Hashtbl with type key = stmt and type data = bool


val create_new_var: string -> typ -> varinfo
(** Create and register a new variable inside Frama-C. The variable
    has its [vlogic] field set, meaning it is not a source variable. The
    freshness of the name must be ensured by the user. *)

val is_const_write_invalid: typ -> bool
(** Detect that the type is const, and that option [-global-const] is set. In
    this case, we forbid writing in a l-value that has this type. *)

val find_return_var: kernel_function -> varinfo option
(** Returns the varinfo returned by the given function.
    Returns None if the function returns void or has no return statement. *)

val postconditions_mention_result: Cil_types.funspec -> bool
(** Does the post-conditions of this specification mention [\result]? *)

val conv_relation: relation -> Abstract_interp.Comp.t

val lval_to_exp: lval -> exp
(** This function is memoized to avoid creating too many expressions *)

(** Computes the height of an expression, that is the maximum number of nested
    operations in this expression. *)
val height_expr: exp -> int

(** Computes the height of an lvalue. *)
val height_lval: lval -> int

val skip_specifications: kernel_function -> bool
(** Should we skip the specifications of this function, according to
    [-eva-skip-stdlib-specs] *)
