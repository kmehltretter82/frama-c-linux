(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(* -------------------------------------------------------------------------- *)
(* --- Region Analysis API                                                --- *)
(* -------------------------------------------------------------------------- *)

type map = Memory.map
type node = Memory.node
let map kf = Analysis.get kf
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
let cvars = Memory.cvars
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
