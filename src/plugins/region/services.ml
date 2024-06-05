(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2024                                               *)
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

open Server
module Md = Markdown

let package = Package.package ~plugin:"region" ~title:"Region Analysis" ()

(* -------------------------------------------------------------------------- *)
(* --- Server Data                                                        --- *)
(* -------------------------------------------------------------------------- *)

module Node : Data.S with type t = Memory.node =
struct
  type t = Memory.node
  let jtype = Data.declare ~package ~name:"node" (Jindex "node")
  let to_json n = Json.of_int @@ Memory.id n
  let of_json js = Memory.forge @@ Json.int js
end

module NodeOpt = Data.Joption(Node)
module NodeList = Data.Jlist(Node)

module Range : Data.S with type t = Memory.node Ranges.range =
struct
  type t = Memory.node Ranges.range
  let jtype = Data.declare ~package ~name:"range" @@
    Jrecord [
      "offset", Jnumber ;
      "length", Jnumber ;
      "data", Node.jtype ;
    ]
  let to_json (rg : Memory.node Ranges.range) =
    Json.of_fields [
      "offset", Json.of_int rg.offset ;
      "length", Json.of_int rg.length ;
      "data", Node.to_json rg.data ;
    ]
  let of_json _ = failwith "Region.Range.of_json"
end

module Ranges = Data.Jlist(Range)

module Region: Data.S with type t = Memory.region =
struct
  type t = Memory.region
  let jtype = Data.declare ~package ~name:"region" @@
    Jrecord [
      "roots", Jarray Jalpha ;
      "parents", NodeList.jtype ;
      "sizeof", Jnumber ;
      "ranges", Ranges.jtype ;
      "pointsTo", NodeOpt.jtype ;
    ]

  let roots_to_json vs =
    let open Cil_types in
    Json.of_list @@ List.map (fun v -> Json.of_string v.vname) vs

  let to_json (m: Memory.region) =
    Json.of_fields [
      "roots", roots_to_json m.roots ;
      "parents", NodeList.to_json m.parents ;
      "sizeof", Json.of_int @@ Memory.sizeof m.layout ;
      "ranges", Ranges.to_json @@ Memory.ranges m.layout ;
      "pointsTo", NodeOpt.to_json @@ Memory.points_to m.layout ;
    ]
  let of_json _ = failwith "Region.Layout.of_json"
end

module Regions = Data.Jlist(Region)

(* -------------------------------------------------------------------------- *)
(* --- Server API                                                         --- *)
(* -------------------------------------------------------------------------- *)
