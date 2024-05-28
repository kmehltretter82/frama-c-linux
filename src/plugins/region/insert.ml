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

open Cil_types
open Memory

[@@@ warning "-a"]

let rec lval (m: map) (lv : lval) : node =
  let h = fst lv in
  offset m (host m h) (Cil.typeOfLhost h) (snd lv)

and host (m: map) = function
  | Var x -> Memory.root m x
  | Mem e -> assert false

and offset (m: map) (r: node) (ty: typ)= function
  | NoOffset -> r
  | Field(fd,ofs) ->
    let size = Cil.bitsSizeOf ty in
    let offset, length = Cil.fieldBitsOffset fd in
    assert false
  | Index(exp,ofs) -> assert false
