(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2022                                               *)
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

(** Calls to the GMP's API. *)

open Cil_types

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

module Z : sig

  val name_arith_bop: binop -> string
  (** [name_of_mpz_arith_bop bop] returns the name of the GMP function on integer
      corresponding to the [bop] arithmetic operation. *)

end

module Q : sig

  val name_arith_bop: binop -> string
  (** [name_of_mpz_arith_bop bop] returns the name of the GMP function on integer
      corresponding to the [bop] arithmetic operation. *)

end

val normalize_str: string -> string
(** Normalize the string so that it fits the representation used by the
    underlying real library. For example, "0.1" is a real number in ACSL
    whereas it is considered as a double by [libgmp] because it is written in
    decimal expansion. In order to make [libgmp] consider it to be a rational,
    it must be converted into "1/10". *)


(*
Local Variables:
compile-command: "make -C ../../../../.."
End:
*)
