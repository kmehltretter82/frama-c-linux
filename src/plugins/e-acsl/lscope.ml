(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2018                                               *)
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


type lscope_var =
  | LvsLet of logic_var * term
  | LvsQuantif of term * logic_var * term
  | LvsFormal of logic_var * logic_info
  | LvsGlobal of logic_var * term

type lscope = lscope_var list

let add lscope lvs = lvs :: lscope

let rec get_lscope_var lv lscope =
  match lscope with
  | [] ->
    None
  | lvs :: lscope' ->
    match lvs with
    | LvsLet(lv', _) | LvsQuantif(_, lv', _)
    | LvsFormal(lv', _) | LvsGlobal(lv', _) ->
      if lv.lv_name = lv'.lv_name then Some lvs
      else get_lscope_var lv lscope'

module H_malloc_free = Hashtbl.Make(struct
  type t = fundec
  let equal (f1:fundec) f2 = Cil_datatype.Fundec.equal f1 f2
  let hash = Cil_datatype.Fundec.hash
end)
let tbl_malloc_free : (stmt list * stmt list) H_malloc_free.t =
  (* The first (resp.second) list is for malloc (resp. free) stmts *)
  H_malloc_free.create 7

let add_malloc_and_free_stmt fundec (malloc_stmt, free_stmt) =
  try
    let malloc_stmts, free_stmts = H_malloc_free.find tbl_malloc_free fundec in
    H_malloc_free.add
      tbl_malloc_free
      fundec (malloc_stmt :: malloc_stmts, free_stmt :: free_stmts)
  with Not_found ->
    H_malloc_free.add tbl_malloc_free fundec  ([malloc_stmt], [free_stmt])

let get_malloc_and_free_stmts fundec =
  try H_malloc_free.find tbl_malloc_free fundec
  with Not_found -> [], []