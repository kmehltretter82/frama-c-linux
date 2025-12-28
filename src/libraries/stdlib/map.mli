(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** Extension of OCaml's {!Stdlib.Maps} module.
    @see <https://frama-c.com/download/frama-c-plugin-development-guide.pdf>
    @since Frama-C+dev
*)

include module type of Stdlib.Map

(** Extension of {!Stdlib.Map.S}. *)
module type S = sig
  include S

  (** Pretty prints a set given printers for keys and values. *)
  val pretty :
    (Format.formatter -> key -> unit) ->
    (Format.formatter -> 'a -> unit) ->
    Format.formatter -> 'a t -> unit
end


module Make (Ord: OrderedType) : S with type key = Ord.t
