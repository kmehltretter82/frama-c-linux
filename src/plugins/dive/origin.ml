(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2022                                               *)
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

open Dive_types

type t = dependency_origin

let (<?>) c lcmp =
  if c <> 0 then c else Lazy.force lcmp

let compare o1 o2 =
  match o1, o2 with
  | Stmt s1, Stmt s2 -> Cil_datatype.Stmt.compare s1 s2
  | Stmt _, _ -> 1
  | _, Stmt _ -> -1
  | GlobalInit v1, GlobalInit v2 -> Cil_datatype.Varinfo.compare v1 v2
  | GlobalInit _, _ -> 1
  | _, GlobalInit _ -> -1
  | FormalAssign (v1, _kf1, s1), FormalAssign (v2, _kf2, s2) ->
    Cil_datatype.Varinfo.compare v1 v2 <?>
    (* if formals are equal, the defining kfs must also be equal *)
    lazy (Cil_datatype.Stmt.compare s1 s2)

let to_kinstr = function
  | Stmt stmt -> Cil_types.Kstmt stmt
  | GlobalInit _vi -> Kglobal
  | FormalAssign (_vi,_kf,stmt) -> Kstmt stmt
