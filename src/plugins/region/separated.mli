(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Memory
open Condition

(** Objects map *)
type objmap

val create : unit -> objmap
val add : objmap -> node:node -> from:node -> string -> addr -> unit
val iter : (string -> addr -> string -> addr -> unit) -> objmap -> unit
