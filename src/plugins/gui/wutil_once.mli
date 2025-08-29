(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** [once f] returns a function that will only be applied once per
    execution of the program and returns the same value afterwards. *)
val once: ('a -> 'b) -> 'a -> 'b
