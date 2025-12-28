(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** Extend the [list] type to a full fleshed monad. This monad can be used
    to represent non-deterministic computations.
    @since 31.0-Gallium *)

include Monad.S_with_product with type 'a t = 'a list
include module type of Stdlib.List

(** Same as {!Stdlib.List.fold_left} but with the argument order reversed.
    @since Frama-C+dev *)
val fold : ('a -> 'acc -> 'acc) -> 'a t -> 'acc -> 'acc

(** Compute a hash for the set given a hash for the elements.
    @since Frama-C+dev *)
val hash : ('a -> int) -> 'a t -> int

(** Pretty prints a set given a printer for the elements.
    @since Frama-C+dev *)
val pretty :
  (Format.formatter -> 'a -> unit) ->
  Format.formatter -> 'a t -> unit
