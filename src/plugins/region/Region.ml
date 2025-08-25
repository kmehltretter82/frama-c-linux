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
let uid n = Memory.uid n
let iter = Memory.iter
let find m id = Memory.normalize @@ Memory.id_to_node m id
let normalize = Memory.normalize
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
let parents n = Memory.nodes @@ Memory.parents n
let points_to n = Option.map Memory.normalize @@ Memory.points_to n
let pointed_by n = Memory.nodes @@ Memory.pointed_by n
let lval m l = Memory.normalize @@ Memory.lval m l
let exp m e = Option.map Memory.normalize @@ Memory.exp m e
let cvar = Memory.cvar
let field = Memory.field
let index = Memory.index
let footprint = Memory.footprint
