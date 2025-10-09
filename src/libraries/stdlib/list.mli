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
