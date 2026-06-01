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

val of_tau : ('f,'a) datatype -> sort
val of_poly : (int -> sort) -> ('f,'a) datatype -> sort
val image : sort -> sort

val merge : sort -> sort -> sort
val merge_list : ('a -> sort) -> sort -> 'a list -> sort

val basename : sort -> string
val pretty : Format.formatter -> sort -> unit

val pp_tvar : Format.formatter -> int -> unit

val pp_tau :
  (Format.formatter -> int -> unit) ->
  (Format.formatter -> 'f -> unit) ->
  (Format.formatter -> 'a -> unit) ->
  Format.formatter -> ('f,'a) datatype -> unit

val pp_data :
  (Format.formatter -> 'a -> unit) ->
  (Format.formatter -> 'b -> unit) ->
  Format.formatter -> 'a -> 'b list -> unit

val pp_record:
  (Format.formatter -> 'f -> unit) ->
  (Format.formatter -> 'b -> unit) ->
  Format.formatter -> ?opened:bool -> ('f * 'b) list -> unit

val eq_tau :
  ('f -> 'f -> bool) ->
  ('a -> 'a -> bool) ->
  ('f,'a) datatype -> ('f,'a) datatype -> bool

val compare_tau:
  ('f -> 'f -> int) ->
  ('a -> 'a -> int) ->
  ('f,'a) datatype -> ('f,'a) datatype -> int

val map_tau:
  ('f1 -> 'f2) ->
  ('a1 -> 'a2) ->
  ('f1,'a1) datatype -> ('f2,'a2) datatype

module MakeTau(F : Field)(A : Data) :
  Data with type t = (F.t,A.t) datatype
