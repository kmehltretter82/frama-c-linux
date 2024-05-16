(**************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2024                                               *)
(*    CEA (Commissariat a l'energie atomique et aux energies              *)
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

open Lang

(** VList Theory Builtins

    Empty API, the module only registers builtins. *)

val check_tau : tau -> bool
val check_term : F.term -> bool
val alist : tau -> tau (* element -> list of element *)
val elist : tau -> tau option (* list -> element *)

class type engine =
  object
    method callstyle : Qed.Engine.callstyle
    method pp_atom : Format.formatter -> F.term -> unit
    method pp_flow : Format.formatter -> F.term -> unit
  end

val f_nil : Fun.t
val f_elt : Fun.t
val f_nth : Fun.t
val f_cons : Fun.t
val f_concat : Fun.t
val f_repeat : Fun.t

val list : F.term list -> F.term
val concat : F.term list -> F.term
val repeat : F.term -> F.term -> F.term

val export : #engine -> Format.formatter -> F.term list -> unit
val pretty : #engine -> Format.formatter -> F.term list -> unit
val elements : #engine -> Format.formatter -> F.term list -> unit
val pprepeat : #engine -> Format.formatter -> F.term list -> unit
val shareable : F.term -> bool

val specialize_eq_list: Lang.For_export.specific_equality
