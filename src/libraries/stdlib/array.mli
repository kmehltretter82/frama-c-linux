(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** Extension of OCaml's {!Stdlib.Array} module.
    @see <https://frama-c.com/download/frama-c-plugin-development-guide.pdf>
    @since Frama-C+dev *)

include module type of Stdlib.Array

(** Same as {!Stdlib.Array.equal} but made available here until the
    minimal supported version is OCaml 5.4. *)
val equal: ('a -> 'a -> bool) -> 'a t -> 'a t -> bool

(** Same as {!Stdlib.Array.compare} but made available here until the
    minimal supported version is OCaml 5.4. *)
val compare: ('a -> 'a -> int) -> 'a t -> 'a t -> int

(** Compute a hash for the set given a hash for the elements. *)
val hash : ('a -> int) -> 'a t -> int

(** Pretty prints a set given a printer for the elements. *)
val pretty :
  (Format.formatter -> 'a -> unit) ->
  Format.formatter -> 'a t -> unit
