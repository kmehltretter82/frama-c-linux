(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

include Stdlib.Map

module type S = sig
  include S
  val pretty :
    (Format.formatter -> key -> unit) ->
    (Format.formatter -> 'a -> unit) ->
    Format.formatter -> 'a t -> unit
  val closed_union : (key -> 'a -> 'a -> 'a) -> 'a t -> 'a t -> 'a t
end

module Make (Ord : OrderedType) =
struct
  include Make (Ord)

  let pretty pp_key pp_val fmt s =
    let pp_item fmt (k,v) =
      Format.fprintf fmt "%a ->@ %a" pp_key k pp_val v
    in
    Pretty.pretty_seq
      ~format:"{{ %t }}" ~item:"%a" ~sep:";@ " ~empty:"{{}}"
      pp_item fmt (to_seq s)

  let closed_union f m1 m2 =
    union (fun k v1 v2 -> Some (f k v1 v2)) m1 m2
end
