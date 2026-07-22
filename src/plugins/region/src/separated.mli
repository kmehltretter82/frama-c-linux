(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Memory

type map
type obj = { named : string ; flags : Attr.flags ; addr : Condition.addr }

val create : unit -> map
val add : map -> node:node -> from:node -> obj -> unit
val iter : (node -> obj -> unit) -> map -> unit
val iter2 : (node -> obj -> obj -> unit) -> map -> unit
