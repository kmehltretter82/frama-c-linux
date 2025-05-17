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

  let pretty_loc fmt (stmt, cs) =
    let stmt_loc = Stmt.loc stmt in
    Format.fprintf fmt "%a <-@ %a"
      Printer.pp_location stmt_loc
      Callstack.pretty cs
end

module Global = struct
  include Cil_datatype.Global
  let name = "Analysis_location.Global"

  let pos gloc =
    fst (loc gloc)

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

let of_stmt stmt : t = Local (stmt, Eva_utils.current_call_stack ())

let of_varinfo vi : t =
  let initinfo = Globals.Vars.find vi in
  Global (GVar (vi, initinfo, vi.vdecl))
let of_kf kf : t = Global (Kernel_function.get_global kf)

let of_call (call : ('a, 'b) Eval.call) =
  let (kf, callsite), caller_stack = Callstack.pop_call call.callstack in
  assert (Kernel_function.equal kf call.kf);
  match callsite, call.return with
  | Kglobal, Some vi -> of_varinfo vi
  | Kglobal, None -> of_kf call.kf
  | Kstmt stmt, _ -> Local (stmt, Option.get caller_stack)

let of_kinstr_lval (kinstr : Cil_types.kinstr) (lval : Eva_ast.lval) =
  match kinstr, lval with
  | Kglobal, { node = (Var vi, _) } -> of_varinfo vi
  | Kstmt stmt, _ -> of_stmt stmt
  | _ ->
    Self.fatal ~current:true
      "Incompatible combination. The only possible `kinstr/lval' couples are \
       `Kglobal/Var' or `Kstmt/_'@;kinstr: %a@ lval: %a"
      Kinstr.pretty kinstr
      Eva_ast.Lval.pretty lval
