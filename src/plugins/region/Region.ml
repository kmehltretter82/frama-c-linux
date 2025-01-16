(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2025                                               *)
(*    CEA (Commissariat à l'énergie atomique et aux énergies              *)
(*         alternatives)                                                  *)
(*                                                                        *)
(*  you can redistribute it and/or modify it under the terms of the GNU   *)
(*  Lesser General Public License as published by the Free Software       *)
(*  Foundation, version 2.1.                                              *)
(*                                                                        *)
(*  It is distributed in the hope that it will be useful,                 *)
(*  but WITHOUT ANY WARRANTY; without even the implied warranty of        *)
(*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *)
(*  GNU Lesser General Public License for more details.                   *)
(*                                                                        *)
(*  See the GNU Lesser General Public License version 2.1                 *)
(*  for more details (enclosed in the file licenses/LGPLv2.1).            *)
(*                                                                        *)
(**************************************************************************)

(* -------------------------------------------------------------------------- *)
(* --- Region Analysis API                                                --- *)
(* -------------------------------------------------------------------------- *)

type map = Memory.map
type node = Memory.node
let map kf = (Analysis.get kf).map
let id n = Memory.id n
let uid m n = Memory.id @@ Memory.node m n
let iter = Memory.iter
let find m id = Memory.node m @@ Memory.forge id
let node = Memory.node
let nodes = Memory.nodes
let equal = Memory.equal
let included = Memory.included
let separated = Memory.separated
let singleton = Memory.singleton
let size = Memory.size
let roots = Memory.roots
let labels = Memory.labels
let reads = Memory.reads
let writes = Memory.writes
let shifts = Memory.shifts
let typed = Memory.typed
let parents m n = Memory.nodes m @@ Memory.parents m n
let points_to m n = Option.map (Memory.node m) @@ Memory.points_to m n
let pointed_by m n = Memory.nodes m @@ Memory.pointed_by m n
let lval m l = Memory.node m @@ Memory.lval m l
let exp m e = Option.map (Memory.node m) @@ Memory.exp m e
let cvar = Memory.cvar
let field = Memory.field
let index = Memory.index
let footprint = Memory.footprint
