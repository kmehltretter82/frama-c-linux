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

module Range : Data.S with type t = Memory.range =
struct
  type t = Memory.range
  let jtype = Data.declare ~package ~name:"range" @@
    Jrecord [
      "label", Jstring ;
      "offset", Jnumber ;
      "length", Jnumber ;
      "cells", Jnumber ;
      "data", Node.jtype ;
    ]

  let to_json (rg : Memory.range) =
    Json.of_fields [
      "label", Json.of_string rg.label ;
      "offset", Json.of_int rg.offset ;
      "length", Json.of_int rg.length ;
      "cells", Json.of_int rg.cells ;
      "data", Node.to_json rg.data ;
    ]
  let of_json _ = failwith "Region.Range.of_json"
end

module Ranges = Data.Jlist(Range)

module Region: Data.S with type t = Memory.region =
struct
  type t = Memory.region

  let roots_to_json vs =
    let open Cil_types in
    Json.of_list @@ List.map (fun v -> Json.of_string v.vname) vs

  let labels_to_json ls =
    Json.of_list @@ List.map Json.of_string ls

  let ikind_to_char (ikind : Cil_types.ikind) =
    match ikind with
    | IBool | IUChar -> 'b'
    | IChar | ISChar -> 'c'
    | IInt -> 'i'
    | IUInt -> 'u'
    | IShort -> 's'
    | IUShort -> 'r'
    | ILong | ILongLong -> 'l'
    | IULong | IULongLong -> 'w'

  let fkind_to_char (fkind : Cil_types.fkind) =
    match fkind with
    | FFloat -> 'f'
    | FDouble | FLongDouble -> 'd'

  let typ_to_char (ty: Cil_types.typ) =
    match ty with
    | TVoid _ -> 'b'
    | TPtr _ -> 'p'
    | TInt(ik,_) -> ikind_to_char ik
    | TFloat(fk,_) -> fkind_to_char fk
    | TComp({ cstruct }, _) -> if cstruct then 'S' else 'U'
    | TArray _ -> 'A'
    | TNamed _ -> 'T'
    | TEnum _ -> 'E'
    | TFun _ -> 'F'
    | TBuiltin_va_list _ -> 'x'

  let typs_to_char (typs : Cil_types.typ list) =
    match typs with
    | [] -> '-'
    | [ty] -> typ_to_char ty
    | _ -> 'x'

  let label (m: Memory.region) =
    let buffer = Buffer.create 4 in
    if m.reads <> [] then Buffer.add_char buffer 'R' ;
    if m.writes <> [] then Buffer.add_char buffer 'W' ;
    if m.pointed <> None then Buffer.add_char buffer '*'
    else if m.reads <> [] || m.writes <> [] then
      begin
        Buffer.add_char buffer '(' ;
        Buffer.add_char buffer @@ typs_to_char m.types ;
        Buffer.add_char buffer ')' ;
      end ;
    Buffer.contents buffer

  let pp_typ_layout s0 fmt ty =
    let s = Cil.bitsSizeOf ty in
    if s <> s0 then
      Format.fprintf fmt "(%a)%%%db" Typ.pretty ty s
    else
      Typ.pretty fmt ty

  let title (m: Memory.region) =
    Format.asprintf "%t (%db)"
      begin fun fmt ->
        match m.types with
        | [] -> Format.pp_print_string fmt "Compound"
        | [ty] -> pp_typ_layout m.sizeof fmt ty ;
        | ty::ts ->
          pp_typ_layout 0 fmt ty ;
          List.iter (Format.fprintf fmt ", %a" (pp_typ_layout 0)) ts ;
      end m.sizeof

  let jtype = Data.declare ~package ~name:"region" @@
    Jrecord [
      "node", Node.jtype ;
      "roots", Jarray Jalpha ;
      "labels", Jarray Jalpha ;
      "parents", NodeList.jtype ;
      "sizeof", Jnumber ;
      "ranges", Ranges.jtype ;
      "pointed", NodeOpt.jtype ;
      "reads", Jboolean ;
      "writes", Jboolean ;
      "bytes", Jboolean ;
      "label", Jstring ;
      "title", Jstring ;
    ]

  let to_json (m: Memory.region) =
    Json.of_fields [
      "node", Node.to_json m.node ;
      "roots", roots_to_json m.roots ;
      "labels", labels_to_json m.labels ;
      "parents", NodeList.to_json m.parents ;
      "sizeof", Json.of_int @@ m.sizeof ;
      "ranges", Ranges.to_json @@ m.ranges ;
      "pointed", NodeOpt.to_json @@ m.pointed ;
      "reads", Json.of_bool (m.reads <> []) ;
      "writes", Json.of_bool (m.writes <> []) ;
      "bytes", Json.of_bool (List.length m.types > 1) ;
      "label", Json.of_string @@ label m ;
      "title", Json.of_string @@ title m ;
    ]

  let of_json _ = failwith "Region.Layout.of_json"
end

module Regions = Data.Jlist(Region)

(* -------------------------------------------------------------------------- *)
(* --- Server API                                                         --- *)
(* -------------------------------------------------------------------------- *)

let map_of_localizable ?(atStmt=false) (loc : Printer_tag.localizable) =
  let open Printer_tag in
  match kf_of_localizable loc with
  | None -> raise Not_found
  | Some kf ->
    let domain = Analysis.find kf in
    if atStmt then
      match ki_of_localizable loc with
      | Kglobal -> domain.map
      | Kstmt s -> Stmt.Map.find s domain.body
    else domain.map

let region_of_localizable (m: Memory.map) (loc: Printer_tag.localizable) =
  try
    match loc with
    | PExp(_,_,e) -> Memory.exp m e
    | PLval(_,_,lv) -> Some (Memory.lval m lv)
    | PVDecl(_,_,x) -> Some (Memory.lval m (Var x,NoOffset))
    | PStmt _ | PStmtStart _
    | PTermLval _ | PGlobal _ | PIP _ | PType _ -> None
  with Not_found -> None

let map_of_declaration (decl : Printer_tag.declaration) =
  match decl with
  | SFunction kf -> (Analysis.find kf).map
  | _ -> raise Not_found

let signal = Request.signal ~package ~name:"updated"
    ~descr:(Md.plain "Region Analysis Updated")

let () = Analysis.add_hook (fun () -> Request.emit signal)

let () =
  Request.register
    ~package ~kind:`EXEC ~name:"compute"
    ~descr:(Md.plain "Compute regions for the given declaration")
    ~input:(module Kernel_ast.Decl)
    ~output:(module Data.Junit)
    (function SFunction kf -> Analysis.compute kf | _ -> ())

let () =
  Request.register
    ~package ~kind:`GET ~name:"regions"
    ~descr:(Md.plain "Returns computed regions for the given declaration")
    ~input:(module Kernel_ast.Decl)
    ~output:(module Regions)
    ~signals:[signal]
    begin fun decl ->
      try Memory.regions @@ map_of_declaration decl
      with Not_found -> []
    end

let () =
  Request.register
    ~package ~kind:`GET ~name:"regionsAt"
    ~descr:(Md.plain "Compute regions at the given marker program point")
    ~input:(module Kernel_ast.Marker)
    ~output:(module Regions)
    ~signals:[signal]
    begin fun loc ->
      try Memory.regions @@ map_of_localizable ~atStmt:true loc
      with Not_found -> []
    end

let () =
  Request.register
    ~package ~kind:`GET ~name:"localize"
    ~descr:(Md.plain "Localize the marker in its map")
    ~input:(module Kernel_ast.Marker)
    ~output:(module NodeOpt)
    ~signals:[signal]
    begin fun loc ->
      try
        let map = map_of_localizable loc in
        region_of_localizable map loc
      with Not_found -> None
    end

(* -------------------------------------------------------------------------- *)
