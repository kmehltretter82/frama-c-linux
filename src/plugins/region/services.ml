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

open Cil_datatype
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
      "reads", Jboolean ;
      "writes", Jboolean ;
      "shifts", Jboolean ;
      "types", Jarray Kernel_ast.Marker.jtype ;
    ]

  let roots_to_json vs =
    let open Cil_types in
    Json.of_list @@ List.map (fun v -> Json.of_string v.vname) vs

  let typ_to_json typ =
    Kernel_ast.Marker.to_json @@ Printer_tag.PType typ

  let to_json (m: Memory.region) =
    Json.of_fields [
      "roots", roots_to_json m.roots ;
      "parents", NodeList.to_json m.parents ;
      "sizeof", Json.of_int @@ Memory.sizeof m.layout ;
      "ranges", Ranges.to_json @@ Memory.ranges m.layout ;
      "pointsTo", NodeOpt.to_json @@ Memory.points_to m.layout ;
      "reads", Json.of_bool @@ not @@ Access.Set.is_empty m.reads ;
      "writes", Json.of_bool @@ not @@ Access.Set.is_empty m.writes ;
      "shifts", Json.of_bool @@ not @@ Access.Set.is_empty m.shifts ;
      "types", Json.of_list @@ List.map typ_to_json @@ Memory.types m ;
    ]
  let of_json _ = failwith "Region.Layout.of_json"
end

module Regions = Data.Jlist(Region)

(* -------------------------------------------------------------------------- *)
(* --- Server API                                                         --- *)
(* -------------------------------------------------------------------------- *)

let regions map =
  let pool = ref [] in
  Memory.iter map (fun _ r -> pool := r :: !pool) ;
  List.rev !pool

let map_of_localizable (loc : Printer_tag.localizable) =
  let open Printer_tag in
  match kf_of_localizable loc with
  | None -> raise Not_found
  | Some kf ->
    let domain = Analysis.find kf in
    match ki_of_localizable loc with
    | Kglobal -> domain.map
    | Kstmt s -> Stmt.Map.find s domain.body

let map_of_declaration (decl : Printer_tag.declaration) =
  match decl with
  | SFunction kf -> (Analysis.find kf).map
  | _ -> raise Not_found

let () =
  Request.register
    ~package ~kind:`EXEC ~name:"compute"
    ~descr:(Md.plain "Compute region domain for the given declaration")
    ~input:(module Kernel_ast.Decl)
    ~output:(module Data.Junit)
    (function SFunction kf -> Analysis.compute kf | _ -> ())

let () =
  Request.register
    ~package ~kind:`GET ~name:"regions"
    ~descr:(Md.plain "Compute regions for the given declaration")
    ~input:(module Kernel_ast.Decl)
    ~output:(module Regions)
    begin fun decl ->
      try regions @@ map_of_declaration decl
      with Not_found -> []
    end

let () =
  Request.register
    ~package ~kind:`GET ~name:"regionsAt"
    ~descr:(Md.plain "Compute regions at the given marker position")
    ~input:(module Kernel_ast.Marker)
    ~output:(module Regions)
    begin fun loc ->
      try regions @@ map_of_localizable loc
      with Not_found -> []
    end

(* -------------------------------------------------------------------------- *)
