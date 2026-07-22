(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(* -------------------------------------------------------------------------- *)
(* --- Sort and Types Tools                                               --- *)
(* -------------------------------------------------------------------------- *)

(** Logic Types Utilities *)

open Logic

val of_tau : 'a datatype -> sort
val of_poly : (int -> sort) -> 'a datatype -> sort
val image : sort -> sort

val merge : sort -> sort -> sort
val merge_list : ('a -> sort) -> sort -> 'a list -> sort

val basename : sort -> string
val pretty : Format.formatter -> sort -> unit

val pp_tvar : Format.formatter -> int -> unit

val pp_tau :
  (Format.formatter -> int -> unit) ->
  (Format.formatter -> 'a -> unit) ->
  Format.formatter -> 'a datatype -> unit

val pp_data :
  (Format.formatter -> 'a -> unit) ->
  (Format.formatter -> 'b -> unit) ->
  Format.formatter -> 'a -> 'b list -> unit

val pp_record:
  (Format.formatter -> 'f -> unit) ->
  (Format.formatter -> 'b -> unit) ->
  Format.formatter -> ?opened:bool -> ('f * 'b) list -> unit

val hash_tau :
  ('a -> int) ->
  'a datatype -> int

val eq_tau :
  ('a -> 'a -> bool) ->
  'a datatype -> 'a datatype -> bool

val compare_tau:
  ('a -> 'a -> int) ->
  'a datatype -> 'a datatype -> int

val map_tau:
  ('a1 -> 'a2) ->
  'a1 datatype -> 'a2 datatype

val map_element : ('a -> 'b) -> 'a element -> 'b element
val map_operator : ('a -> 'b) -> 'a operator -> 'b operator
val map_category : ('a -> 'b) -> 'a category -> 'b category

module MakeTau(A : Data) : Data with type t = A.t datatype
