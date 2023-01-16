(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C plug-in 'Alias' (alias).             *)
(*                                                                        *)
(*  Copyright (C) 2022-2023                                               *)
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
(*  for more details (enclosed in the file LICENSE)                       *)
(*                                                                        *)
(**************************************************************************)

open Cil_types

open Cil_datatype

module LSet = Lval.Set


let fold_new_aliases_stmt
    (f_fold : 'a -> lval -> 'a) (acc: 'a) (kf: kernel_function)  (s:stmt) (lv: lval) : 'a =
  match Analysis.get_abstract_state kf s with
    None -> acc
  | Some state ->
    let set_aliases = Abstract_state.find_aliases lv state in
    LSet.fold (fun e a -> f_fold a e) set_aliases acc

let fold_aliases_stmt
    (f_fold: 'a -> lval -> 'a) (acc: 'a) (kf:kernel_function) (s:stmt) (lv:lval) : 'a =
  (* TODO is it correct ? obviously not *)
  match s.preds with
    [] -> acc
  | s::_ -> fold_new_aliases_stmt f_fold acc kf s lv

let fold_aliases_kf
    (f_fold: 'a -> lval -> 'a) (acc: 'a) (kf:kernel_function) (lv:lval) : 'a =
  let s = Kernel_function.find_return kf in
  fold_new_aliases_stmt f_fold acc kf s lv

let fold_fundec_stmts _ =
  failwith "not implemented"

let are_aliased (kf: kernel_function)  (s:stmt) (lv1: lval) (lv2:lval) : bool =
  match Analysis.get_abstract_state kf s with
    None -> false
  | Some state ->
    let setv1 = Abstract_state.find_aliases lv1 state in
    LSet.mem lv2 setv1

let fold_points_to _ =
  failwith "not implemented"

let fold_points_to_closure  _ =
  failwith "not implemented"
