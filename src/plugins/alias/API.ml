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

(** Points-to graphs datastructure. *)
module G = Abstract_state.G

let vid = Abstract_state.vid

module LSet = Abstract_state.LSet

module Abstract_state = Abstract_state

let check_computed () =
  if not (Analysis.is_computed ())
  then
    Options.abort "Static analysis must be called before any function of the API can be called"


let lset
    (get_set : Abstract_state.t -> LSet.t)
    (kf : kernel_function) (s : stmt) =
  check_computed ();
  match Analysis.get_state_before_stmt kf s with
  | None -> LSet.empty
  | Some state -> get_set state

let points_to_set_stmt kf s lv = lset (Abstract_state.points_to_set lv) kf s

let new_points_to_set_stmt kf s lv =
  let get_set state =
    let new_state = Analysis.do_stmt state s in
    Abstract_state.points_to_set lv new_state
  in
  lset get_set kf s

let aliases_stmt kf s lv =
  lset (Abstract_state.find_all_aliases lv) kf s

let new_aliases_stmt kf s lv =
  let get_set state =
    let new_state = Analysis.do_stmt state s in
    Abstract_state.find_all_aliases lv new_state
  in
  lset get_set kf s

let points_to_set_kf (kf : kernel_function) (lv : lval) =
  check_computed ();
  if Kernel_function.has_definition kf
  then
    let s = Kernel_function.find_return kf in
    new_points_to_set_stmt kf s lv
  else
    Options.abort "points_to_set_kf: function %a has no definition" Kernel_function.pretty kf

let aliases_kf (kf : kernel_function) (lv : lval) =
  check_computed ();
  if Kernel_function.has_definition kf
  then
    let s = Kernel_function.find_return kf in
    new_aliases_stmt kf s lv
  else
    Options.abort "aliases_kf: function %a has no definition" Kernel_function.pretty kf

let fundec_stmts (kf : kernel_function) (lv : lval) =
  check_computed ();
  if Kernel_function.has_definition kf
  then
    List.map
      (fun s -> s, new_aliases_stmt kf s lv)
      (Kernel_function.get_definition kf).sallstmts
  else
    Options.abort "fundec_stmts: function %a has no definition" Kernel_function.pretty kf


let fold_points_to_set f_fold acc kf s lv =
  LSet.fold (fun e a -> f_fold a e) (points_to_set_stmt kf s lv) acc

let fold_aliases_stmt f_fold acc kf s lv =
  LSet.fold (fun e a -> f_fold a e) (aliases_stmt kf s lv) acc

let fold_new_aliases_stmt f_fold acc kf s lv =
  LSet.fold (fun e a -> f_fold a e) (new_aliases_stmt kf s lv) acc

let fold_points_to_set_kf (f_fold: 'a -> lval -> 'a) (acc: 'a) (kf:kernel_function) (lv:lval) : 'a =
  LSet.fold (fun e a -> f_fold a e) (points_to_set_kf kf lv) acc

let fold_aliases_kf (f_fold : 'a -> lval -> 'a) (acc : 'a) (kf : kernel_function) (lv : lval) : 'a =
  LSet.fold (fun e a -> f_fold a e) (aliases_kf kf lv) acc

let fold_fundec_stmts (f_fold: 'a -> stmt -> lval -> 'a) (acc: 'a) (kf:kernel_function) (lv:lval) : 'a =
  List.fold_left
    (fun acc (s, set) ->
       LSet.fold (fun lv a -> f_fold a s lv) set acc
    )
    acc
    (fundec_stmts kf lv)

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
