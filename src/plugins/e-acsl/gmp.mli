(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2018                                               *)
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

(** GMP Values. *)

open Cil_types

(**************************************************************************)
(******************************** Types ***********************************)
(**************************************************************************)

val init_t: unit -> unit
(** Must be called before any use of GMP *)

val set_z_t: typeinfo -> unit
val set_q_t: typeinfo -> unit

val z_t: unit -> typ
(** type [mpz_t] *)

val z_t_ptr: unit -> typ
  (** type "_mpz_struct *" *)

val q_t: unit -> typ
(** type [mpq_t] *)

val is_z_now_referenced: unit -> unit
(** Should be called once one variable of type [mpz_t] exists *)

val is_q_now_referenced: unit -> unit
(** Should be called once one variable of type [mpq_t] exists *)

val is_z_t: typ -> bool
(** is the type equal to [mpz_t]? *)
val is_q_t: typ -> bool
(** is the type equal to [mpq_t]? *)

(**************************************************************************)
(************************* Calls to builtins ******************************)
(**************************************************************************)

val init: loc:location -> exp -> stmt
(** build stmt [mpz_init(v)] or [mpq_init(v)] depending on typ of [v] *)

val init_set: loc:location -> lval -> exp -> exp -> stmt
(** [init_set x_as_lv x_as_exp e] builds stmt [x = e] or [mpz_init_set*(v, e)]
    or [mpq_init_set*(v, e)] with the good function 'set'
    according to the type of [e] *)

val clear: loc:location -> exp -> stmt
(** build stmt [mpz_clear(v)] or [mpq_clear(v)] depending on typ of [v] *)

val affect: loc:location -> lval -> exp -> exp -> stmt
(** [affect x_as_lv x_as_exp e] builds stmt [x = e] or [mpz_set*(e)]
    or [mpq_set*(e)] with the good function 'set'
    according to the type of [e] *)

(*
Local Variables:
compile-command: "make"
End:
*)
