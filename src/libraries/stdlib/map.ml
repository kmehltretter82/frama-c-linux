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

  let pretty pp_key pp_val fmt map =
    Format.fprintf fmt  "@[{{ ";
    iter
      (fun k v ->
          Format.fprintf fmt "@[@[%a@] -> @[%a@]@];@ "
            pp_key k
            pp_val v)
      map;
    Format.fprintf fmt  " }}@]"
end
