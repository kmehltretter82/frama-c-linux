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

  let pos lpos =
    fst (loc lpos)

  let kinstr lpos =
    Cil_types.Kstmt (fst lpos)

  let pretty_loc fmt lpos =
    Printer.pp_location fmt (loc lpos)

  let kf (_stmt, cs) =
    Callstack.top_kf cs

  let stmt (stmt, _cs) =
    stmt

  let callstack (_stmt, cs) =
    cs
end

type local = Local.t

(* Datatype for Analysis_location *)
module Prototype = struct
  include Datatype.Serializable_undefined

  type t =
    | RootCall of Kernel_function.t
    | GlobalInit of Varinfo.t
    | Local of Local.t
  [@@deriving eq, ord]

  let name = "Analysis_location"
  let reprs =
    List.map (fun kf -> RootCall kf) Kernel_function.reprs @
    List.map (fun vi -> GlobalInit vi) Varinfo.reprs @
    List.map (fun local -> Local local) Local.reprs
  let hash = function
    | RootCall kf -> Hashtbl.hash (1, Kernel_function.hash kf)
    | GlobalInit vi -> Hashtbl.hash (2, Varinfo.hash vi)
    | Local l -> Hashtbl.hash (1, Local.hash l)
  let pretty fmt = function
    | RootCall kf -> Format.pp_print_string fmt (Kernel_function.get_name kf)
    | GlobalInit vi -> Format.pp_print_string fmt vi.vname
    | Local l -> Local.pretty fmt l
end
include Datatype.Make_with_collections (Prototype)
include Prototype

let local stmt callstack =
  Local (stmt, callstack)

let root_call kf =
  RootCall kf

let global_init vi =
  GlobalInit vi

let is_local = function
  | RootCall _ | GlobalInit _ -> false
  | Local _ -> true

let loc pos =
  match pos with
  | RootCall kf -> Kernel_function.get_location kf
  | GlobalInit vi -> vi.vdecl
  | Local l -> Local.loc l

let pos pos =
  loc pos |> fst

let kinstr pos =
  match pos with
  | RootCall _ | GlobalInit _ -> Cil_types.Kglobal
  | Local l -> Local.kinstr l

let stmt pos =
  match pos with
  | RootCall _ | GlobalInit _ -> None
  | Local (stmt,_cs) -> Some stmt

let kf pos =
  match pos with
  | RootCall kf -> Some kf
  | GlobalInit _ -> None
  | Local lpos -> Some (Local.kf lpos)

let callstack pos =
  match pos with
  | RootCall kf -> Some (Callstack.init kf)
  | GlobalInit _vi -> None
  | Local lpos -> Some (Local.callstack lpos)

let pretty_loc fmt pos =
  Printer.pp_location fmt (loc pos)

let of_kinstr kinstr callstack =
  match kinstr with
  | Cil_types.Kstmt stmt ->
    Local (stmt, callstack)
  | Kglobal ->
    match Callstack.pop_call callstack with
    | kf, None ->
      RootCall kf
    | _kf, Some (stmt, callstack) ->
      Local (stmt, callstack)

let of_local lpos =
  Local lpos
