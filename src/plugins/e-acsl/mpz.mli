(**************************************************************************)
(*                                                                        *)
(*  This file is part of the E-ACSL plug-in of Frama-C.                   *)
(*                                                                        *)
(*  Copyright (C) 2011                                                    *)
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

val t: typ 
  (** type "mpz_t" *)
  
val is_now_referenced: unit -> unit 
  (** Should be called once one variable of type "mpz_t" exists *)

val is_t: typ -> bool 
  (** is the type equal to "mpz_t"? *)

val init: exp -> stmt
  (** build stmt "mpz_init(v)" *)

val init_set: lval -> exp -> exp -> stmt
(** [init_set x_as_lv x_as_exp e] builds stmt [x = e] or [mpz_init_set*(v, e)]
    with the good function 'set' according to the type of e *)

val clear: exp -> stmt
(** build stmt "mpz_clear(v)" *)

val affect: lval -> exp -> exp -> stmt
(** [affect x_as_lv x_as_exp e] builds stmt [x = e] or [mpz_set*(e)] with the
    good function 'set' according to the type of e *)

(*
Local Variables:
compile-command: "make"
End:
*)
