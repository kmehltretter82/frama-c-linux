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

open Annot
open Memory

let rec add_lval (m:map) (p:path): node =
  match p.step with
  | Var x -> add_root m x
  | Field(lv,fd) -> Memory.add_field m (add_lval m lv) fd
  | Index(lv,n) -> Memory.add_index m (add_lval m lv) lv.typ n
  | Star e | Cast(_,e) -> add_pointer m e
  | Shift _ | AddrOf _ ->
    Options.error ~source:(fst p.loc)
      "Unexpected expression (l-value expected)" ;
    Memory.new_chunk m ()
and add_pointer  (m:map) (p:path): Memory.node =
  match add_exp m p with
  | None -> Memory.new_chunk m ()
  | Some r -> r

and add_exp (m:map) (p:path): Memory.node option =
  match p.step with
  | (Var _ | Field _ | Index _ | Star _ | Cast _) ->
    let r = add_lval m p in
    add_value m r p.typ
  | AddrOf p -> Some (add_lval m p)
  | Shift p -> add_exp m p

let add_region (m: map) (r : Annot.region) =
  let rs = List.map (add_lval m) r.rpath in
  merge_all m @@
  match r.rname with
  | None -> rs
  | Some a -> add_label m a :: rs
