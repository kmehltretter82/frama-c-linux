(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2024                                               *)
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

(** API to perform a Dominators and Postdominators analysis for a kernel
    function.

    A dominator [d] of [s] is a statement such that all paths from the entry
    point of a function to [s] must go through [d].

    A postdominator [p] of [s] is a statement such that all paths from [s] to
    the return point of the function must go through [p].

    By definition, a statement always (post)dominates itself (except if it is
    unreachable).

    An immediate (post)dominator (or i(post)dom) [d] is the unique
    (post)dominator of [s] that strictly (post)dominates [s] but is
    (post)dominated by all other (post)dominators of [s].

    A common ancestor (or children) of a list of statements is a (post)dominator
    that (post)dominates all the statements

    @before Frama-C+dev This module was using [Dataflow2] instead of
    [Interpreted_automata]. The new version also offers more function via its
    API.
*)

open Cil_types

val compute_dominators : kernel_function -> unit
(** Compute the Dominators analysis and register its result.
    @since Frama-C+dev
*)

val compute_postdominators : kernel_function -> unit
(** Compute the Postdominators analysis and register its result.
    @since Frama-C+dev
*)

val get_dominators : stmt -> Cil_datatype.Stmt.Hptset.t
(** Return the [set] of dominators of the given statement.
    The empty set means the statement is unreachable.
    @since Frama-C+dev
*)

val get_postdominators : stmt -> Cil_datatype.Stmt.Hptset.t
(** Return the [set] of postdominators of the given statement.
    The empty set means the statement is unreachable.
    @since Frama-C+dev
*)

val get_strict_dominators : stmt -> Cil_datatype.Stmt.Hptset.t
(** Same as [get_dominators] but exclude the statement itself. The empty set
    means the statement is unreachable or is only dominated by itself.
    @since Frama-C+dev
*)

val get_strict_postdominators : stmt -> Cil_datatype.Stmt.Hptset.t
(** Same as [get_postdominators] but exclude the statement itself. The empty set
    means the statement is unreachable or is only post-dominated by itself.
    @since Frama-C+dev
*)

val dominates : stmt -> stmt -> bool
(** [dominates a b] return [true] if [a] dominates [b]. *)

val postdominates : stmt -> stmt -> bool
(** [postdominates a b] return [true] if [a] postdominates [b].
    @since Frama-C+dev
*)

val strictly_dominates : stmt -> stmt -> bool
(** [strictly_dominates a b] return [true] if [a] strictly dominates [b].
    @since Frama-C+dev
*)

val strictly_postdominates : stmt -> stmt -> bool
(** [strictly_postdominates a b] return [true] if [a] strictly postdominates [b].
    @since Frama-C+dev
*)

val get_idom : stmt -> stmt option
(** Return the immediate dominator of the given statement. *)

val get_ipostdom : stmt -> stmt option
(** Return the immediate postdominator of the given statement.
    @since Frama-C+dev
*)

val nearest_common_ancestor : stmt list -> stmt option
(** Return the closest common ancestor of the given statement list.
    @before Frama-C+dev previous implementation always returned a statement and
    raised a failed assertion in case of unreachable statement.
*)

val nearest_common_children : stmt list -> stmt option
(** Return the closest common children of the given statement list.
    @since Frama-C+dev
*)

val pretty_dominators : Format.formatter -> unit -> unit
(** Print the result of the domination analysis. Each statement is either
    dominated by a set of statements, or [Top] if unreachable.
    @since Frama-C+dev
*)

val pretty_postdominators : Format.formatter -> unit -> unit
(** Print the result of the postdomination analysis. Each statement is either
    postdominated by a set of statements, or [Top] if unreachable.
    @since Frama-C+dev
*)

val print_dot_dominators : string -> kernel_function -> unit
(** Print the domination graph in a file [basename.function_name.dot].
    @since Frama-C+dev
*)

val print_dot_postdominators : string -> kernel_function -> unit
(** Print the postdomination graph in a file [basename.function_name.dot].
    @since Frama-C+dev
*)
