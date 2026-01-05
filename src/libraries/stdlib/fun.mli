(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** Extension of OCaml's {!Stdlib.Fun} module.
    @see <https://frama-c.com/download/frama-c-plugin-development-guide.pdf>
    @since Frama-C+dev *)

include module type of Stdlib.Fun

(** Same as {!Stdlib.Fun.compose} but made available here until the
    minimal supported version is OCaml 5.04. *)
val compose : ('b -> 'c) -> ('a -> 'b) -> 'a -> 'c

module Operators : sig
  (** Function composition. See {!compose}. *)
  val ($) : ('b -> 'c) -> ('a -> 'b) -> 'a -> 'c
end
