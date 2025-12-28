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
end

module Make (Ord : OrderedType) =
struct
  include Make (Ord)

  let pretty pp_key pp_val =
    Collection.pretty_iter2
      ~format:"{{ %t }}" ~item:"%a ->@ %a" ~sep:";@ " ~iter
      pp_key pp_val
end
