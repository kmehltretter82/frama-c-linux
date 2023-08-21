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

module Local =
struct
  module Prototype =
  struct
    open Cil_datatype
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
      Format.fprintf fmt "%a <-@ %a" Stmt.pretty stmt Callstack.pretty cs
  end

  include Datatype.Make_with_collections (Prototype)
end

type local = Local.t
