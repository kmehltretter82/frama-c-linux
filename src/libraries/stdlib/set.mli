(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** Extension of OCaml's {!Stdlib.Set} module.
    @see <https://frama-c.com/download/frama-c-plugin-development-guide.pdf>
    @since Frama-C+dev
*)

include module type of Stdlib.Set

(** Extension of {!Stdlib.Set.S}. *)
module type S = sig
  include S

  (** Compute a hash for the set given a hash for the elements. *)
  val hash : (elt -> int) -> t -> int

  (** Pretty prints a set given a printer for the elements. *)
  val pretty :
    (Format.formatter -> elt -> unit) ->
    Format.formatter -> t -> unit
end


module Make (Ord: OrderedType) : S with type elt = Ord.t
