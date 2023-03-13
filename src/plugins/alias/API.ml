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

module Abstract_state = Abstract_state

let check_computed () =
  if not (Analysis.is_computed ())
  then
    Options.abort "Static analysis must be called before any function of the API can be called"


let fold_aliases_stmt (f_fold : 'a -> lval -> 'a) (acc: 'a) (kf: kernel_function)  (s:stmt) (lv: lval) : 'a =
  check_computed ();
  match Analysis.get_state_before_stmt kf s with
    None -> acc
  | Some state ->
    let set_aliases = Abstract_state.find_aliases lv state in
    LSet.fold (fun e a -> f_fold a e) set_aliases acc

let fold_new_aliases_stmt (f_fold: 'a -> lval -> 'a) (acc: 'a) (kf:kernel_function) (s:stmt) (lv:lval) : 'a =
  check_computed ();
  match Analysis.get_state_before_stmt kf s with
    None -> acc
  | Some state ->
    let new_state = Analysis.do_stmt state s in
    let set_aliases = Abstract_state.find_aliases lv new_state in
    LSet.fold (fun e a -> f_fold a e) set_aliases acc

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
    Options.abort "fold_dundec_stmts: function %a has no definition" Kernel_function.pretty kf

let are_aliased (kf: kernel_function) (s:stmt) (lv1: lval) (lv2:lval) : bool =
  check_computed ();
  match Analysis.get_state_before_stmt kf s with
    None -> false
  | Some state ->
    let setv1 = Abstract_state.find_aliases lv1 state in
    LSet.mem lv2 setv1

let fold_points_to   (f_fold : 'a -> Lval.Set.t -> 'a) (acc: 'a) (kf: kernel_function)  (s:stmt) (lv: lval) : 'a =
  check_computed ();
  match Analysis.get_state_before_stmt kf s with
    None -> acc
  | Some state ->
    let set_aliases = Abstract_state.find_aliases lv state in
    f_fold acc set_aliases

let fold_points_to_closure  (f_fold : 'a -> Lval.Set.t -> 'a) (acc: 'a) (kf: kernel_function)  (s:stmt) (lv: lval) : 'a =
  check_computed ();
  match Analysis.get_state_before_stmt kf s with
    None -> acc
  | Some state ->
    let list_closure = Abstract_state.find_transitive_closure lv state in
    List.fold_left
      f_fold
      acc
      list_closure


let get_state_before_stmt = Analysis.get_state_before_stmt

let call_function a f res args =
  match Analysis.get_summary f with
    None -> None
  | Some su -> Some(Abstract_state.call a res args su)

