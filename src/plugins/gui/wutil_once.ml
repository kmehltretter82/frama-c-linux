(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(* belongs to Wutil, but used by gtk_compat.{2,3}.ml *)

type ('a,'b) cell = Value of 'b | Fun of ('a -> 'b)
let get p x =
  match !p with
  | Value y -> y
  | Fun f -> let y = f x in p := Value y ; y
let once f = get (ref (Fun f))
