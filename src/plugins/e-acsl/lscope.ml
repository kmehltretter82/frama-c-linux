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
  | Lvs_let of logic_var * term
  | Lvs_quantif of term * logic_var * term
  | Lvs_formal of logic_var * logic_info
  | Lvs_global of logic_var * term

type t = lscope_var list
(* The logic scope is usually small, so a list is fine instead of a Map *)

let empty () = []

let is_empty = function [] -> true | _ :: _ -> false

let add t lvs = t @ [lvs]
(* We need to append [lvs], and not prepend it.
  This is so that the first element of the list is
  the first that should be translated,
  the 2nd element the 2nd to be translated and so on. *)

let top = function
  | [] -> None
  | lvs :: lscope -> Some(lvs, lscope)

let rec get_lscope_var lv t =
  match t with
  | [] ->
    None
  | lvs :: t' ->
    match lvs with
    | Lvs_let(lv', _) | Lvs_quantif(_, lv', _)
    | Lvs_formal(lv', _) | Lvs_global(lv', _) ->
      if Cil_datatype.Logic_var.equal lv lv' then Some lvs
      else get_lscope_var lv t'

let effective_lscope_from_pred_or_term pot potential_lscope =
  let effective_lscope = ref (empty ()) in
  let o = object inherit Visitor.frama_c_inplace
    method !vlogic_var_use lv =
      begin match get_lscope_var lv potential_lscope with
      | None -> ()
      | Some lvs -> effective_lscope := add !effective_lscope lvs
      end;
      Cil.DoChildren
  end
  in
  match pot with
  | Misc.PoT_pred p ->
    ignore (Visitor.visitFramacPredicate o p);
    !effective_lscope
  | Misc.PoT_term t ->
    ignore (Visitor.visitFramacTerm o t);
    !effective_lscope