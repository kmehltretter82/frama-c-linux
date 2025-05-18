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

open Cil_datatype

module type S = sig
  include Datatype.S_with_collections
  val loc : t -> Cil_types.location
  val pos : t -> Filepath.position
  val kinstr : t -> Cil_types.kinstr
  val pretty_loc : Format.formatter -> t -> unit
end

module Local =
struct
  module Prototype =
  struct
    include Datatype.Serializable_undefined

    type t = Stmt.t * Callstack.t [@@deriving eq, ord]

    let name = "Analysis_location.Local"
    let reprs =
      List.concat_map
        (fun stmt -> List.map (fun cs -> (stmt,cs)) Callstack.reprs)
        Stmt.reprs
    let hash (stmt, cs) =
      Hashtbl.hash (Stmt.hash stmt, Callstack.hash cs)
    let pretty fmt (stmt,cs) =
      Format.fprintf fmt "%a <-@ %a"
        Cil_datatype.Location.pretty (Stmt.loc stmt)
        Callstack.pretty cs
  end

  include Datatype.Make_with_collections (Prototype)

  let loc (stmt, _cs) =
    Cil_datatype.Stmt.loc stmt

  let pos aloc =
    fst (loc aloc)

  let kinstr aloc =
    Cil_types.Kstmt (fst aloc)

  let pretty_loc fmt (stmt, _cs) =
    let stmt_loc = Stmt.loc stmt in
    Printer.pp_location fmt stmt_loc
end

module Global = struct
  include Cil_datatype.Global
  let name = "Analysis_location.Global"

  let pos gloc =
    fst (loc gloc)

  let kinstr _gloc =
    Cil_types.Kglobal

  let pretty_loc fmt gloc =
    let global_loc = Global.loc gloc in
    Printer.pp_location fmt global_loc
end

(* Datatype for Analysis_location *)
module Prototype = struct
  include Datatype.Serializable_undefined

  type t =
    | Global of Global.t
    | Local of Local.t
  [@@deriving eq, ord]

  let name = "Analysis_location"
  let reprs =
    List.map (fun global -> Global global) Global.reprs @
    List.map (fun local -> Local local) Local.reprs
  let hash = function
    | Local l -> Hashtbl.hash (1, Local.hash l)
    | Global g -> Hashtbl.hash (2, Global.hash g)
  let pretty fmt = function
    | Local l -> Local.pretty fmt l
    | Global g -> Global.pretty fmt g
end
include Datatype.Make_with_collections (Prototype)
include Prototype

let loc aloc =
  match aloc with
  | Local l -> Local.loc l
  | Global g -> Global.loc g

let pos aloc =
  match aloc with
  | Local l -> Local.pos l
  | Global g -> Global.pos g

let kinstr aloc =
  match aloc with
  | Local l -> Local.kinstr l
  | Global g -> Global.kinstr g

let stmt aloc =
  match aloc with
  | Local (stmt,_cs) -> Some stmt
  | Global _ -> None

let kf aloc =
  match aloc with
  | Local (_stmt, cs) -> Some (Callstack.top_kf cs)
  | Global (GFun ({ svar = vi }, _))
  | Global (GFunDecl (_, vi, _)) ->
    (try Some (Globals.Functions.get vi) with Not_found -> None)
  | Global _ -> None

let callstack aloc =
  match aloc with
  | Local (_stmt,cs) -> Some cs
  | Global _ -> None

let pretty_loc fmt aloc =
  match aloc with
  | Local l -> Local.pretty_loc fmt l
  | Global g -> Global.pretty_loc fmt g

type global = Global.t
type local = Local.t

let local stmt callstack =
  Local (stmt, callstack)

let is_local = function
  | Local _ -> true
  | Global _ -> false

let global global =
  Global global

let is_global = function
  | Local _ -> false
  | Global _ -> true

let of_varinfo vi : t =
  let initinfo = Globals.Vars.find vi in
  Global (GVar (vi, initinfo, vi.vdecl))

let of_kf kf =
  Global (Kernel_function.get_global kf)

let of_call (call : ('a, 'b) Eval.call) =
  let kf, lloc = Callstack.pop_call call.callstack in
  assert (Kernel_function.equal kf call.kf);
  match lloc, call.return with
  | None, Some vi -> of_varinfo vi
  | None, None -> of_kf call.kf
  | Some (stmt, caller_stack), _ -> Local (stmt, caller_stack)

let of_kinstr kinstr callstack =
  match kinstr with
  | Cil_types.Kstmt stmt ->
    Local (stmt, callstack)
  | Kglobal ->
    match Callstack.pop_call callstack with
    | kf, None ->
      of_kf kf
    | _kf, Some (stmt, callstack) ->
      Local (stmt, callstack)
