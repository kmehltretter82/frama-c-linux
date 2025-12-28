(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

include Stdlib.Set

module type S = sig
  include S
  val hash : (elt -> int) -> t -> int
  val pretty :
    (Format.formatter -> elt -> unit) ->
    Format.formatter -> t -> unit
end

module Make (Ord : OrderedType) =
struct
  include Make (Ord)

  let hash hash_elt set =
    fold (fun e h -> 67 * hash_elt e + h) set 189

  let pretty pp_elt =
    Collection.pretty_iter
      ~format:"{ %t }" ~item:"%a" ~sep:";@ " ~iter
      pp_elt
end
