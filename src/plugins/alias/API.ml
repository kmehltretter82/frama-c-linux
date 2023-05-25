(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2023                                               *)
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

open Simplified

(** Points-to graphs datastructure. *)
module G = Abstract_state.G

module LSet = Simplified_lset

module Abstract_state = Abstract_state

let check_computed () =
  if not (Analysis.is_computed ())
  then
    Options.abort "Static analysis must be called before any function of the API can be called"


let fold_lset
    (get_set : Abstract_state.t -> LSet.t)
    (f_fold : 'a -> lval -> 'a)
    (acc : 'a) (kf : kernel_function) (s : stmt) : 'a =
  check_computed ();
  match Analysis.get_state_before_stmt kf s with
  | None -> acc
  | Some state ->
    let set = get_set state in
    LSet.fold (fun e a -> f_fold a e) set acc

let fold_points_to_set f_fold acc kf s lv =
  fold_lset (Abstract_state.points_to_set lv) f_fold acc kf s

let fold_new_points_to_set_stmt f_fold acc kf s lv =
  let get_set state =
    let new_state = Analysis.do_stmt state s in
    Abstract_state.points_to_set lv new_state
  in
  fold_lset get_set f_fold acc kf s

let fold_aliases_stmt f_fold acc kf s lv =
  fold_lset (Abstract_state.find_all_aliases lv) f_fold acc kf s

let fold_new_aliases_stmt f_fold acc kf s lv =
  let get_set state =
    let new_state = Analysis.do_stmt state s in
    Abstract_state.find_all_aliases lv new_state
  in
  fold_lset get_set f_fold acc kf s

let fold_points_to_set_kf (f_fold: 'a -> lval -> 'a) (acc: 'a) (kf:kernel_function) (lv:lval) : 'a =
  check_computed ();
  if Kernel_function.has_definition kf
  then
    let s = Kernel_function.find_return kf in
    fold_new_points_to_set_stmt f_fold acc kf s lv
  else
    Options.abort "fold_points_to_set_kf: function %a has no definition" Kernel_function.pretty kf

let fold_aliases_kf (f_fold: 'a -> lval -> 'a) (acc: 'a) (kf:kernel_function) (lv:lval) : 'a =
  check_computed ();
  if Kernel_function.has_definition kf
  then
    let s = Kernel_function.find_return kf in
    fold_new_aliases_stmt f_fold acc kf s lv
  else
    Options.abort "fold_aliases_kf: function %a has no definition" Kernel_function.pretty kf

let fold_fundec_stmts (f_fold: 'a -> stmt -> lval -> 'a) (acc: 'a) (kf:kernel_function) (lv:lval) : 'a =
  check_computed ();
  if Kernel_function.has_definition kf
  then
    let f_dec = Kernel_function.get_definition kf in
    let list_stmt = f_dec.sallstmts in
    List.fold_left
      (fun acc s ->
         fold_new_aliases_stmt
           (fun a lv -> f_fold a s lv)
           acc
           kf
           s
           lv
      )
      acc
      list_stmt
  else
    Options.abort "fold_fundec_stmts: function %a has no definition" Kernel_function.pretty kf

let are_aliased (kf: kernel_function) (s:stmt) (lv1: lval) (lv2:lval) : bool =
  check_computed ();
  match Analysis.get_state_before_stmt kf s with
    None -> false
  | Some state ->
    let setv1 = Abstract_state.find_all_aliases lv1 state in
    LSet.mem lv2 setv1

let fold_vertex (f_fold : 'a -> G.V.t -> lval -> 'a) (acc: 'a) (kf: kernel_function) (s:stmt) (lv: lval) : 'a =
  check_computed ();
  match Analysis.get_state_before_stmt kf s with
    None -> acc
  | Some state ->
    let v : G.V.t = Abstract_state.find_vertex lv state in
    let set_aliases = Abstract_state.find_aliases lv state in
    LSet.fold (fun lv a-> f_fold a v lv) set_aliases acc

let fold_vertex_closure  (f_fold : 'a -> G.V.t -> lval -> 'a) (acc: 'a) (kf: kernel_function)  (s:stmt) (lv: lval) : 'a =
  check_computed ();
  match Analysis.get_state_before_stmt kf s with
    None -> acc
  | Some state ->
    let list_closure : (G.V.t * LSet.t) list = Abstract_state.find_transitive_closure lv state in
    List.fold_left
      (fun acc (i,s) -> LSet.fold (fun lv a -> f_fold a i lv) s acc)
      acc
      list_closure

let get_state_before_stmt =
  Analysis.get_state_before_stmt

let call_function a f res args =
  match Analysis.get_summary f with
    None -> None
  | Some su -> Some(Abstract_state.call a res args su)

let simplify_lval = Simplified.Lval.simplify
