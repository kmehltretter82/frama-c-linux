(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** Extend the [option] type to a full fleshed monad. Be wary that the
    parameters order of the [bind] function are reversed compared to
    the standard library.
    @since 31.0-Gallium *)

include Monad.S_with_product with type 'a t = 'a option
include module type of Stdlib.Option

(** Reverse {!Stdlib.Option.bind} parameters for monad compatibility.
    [bind f o] is [f v] if [o] is [Some v] and [None] if [o] is [None].
*)
val bind: ('a -> 'b t) -> 'a t -> 'b t
