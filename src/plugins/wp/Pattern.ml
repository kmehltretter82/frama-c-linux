(**************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2023                                               *)
(*    CEA (Commissariat a l'energie atomique et aux energies              *)
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

open Logic_typing
open Logic_ptree
open Lang.F

[@@@ warning "-32-37" ] (*TODO*)

(* -------------------------------------------------------------------------- *)
(* --- Pattern Engine                                                     --- *)
(* -------------------------------------------------------------------------- *)

type pvar = { vloc : location ; vname : string ; mutable vtau : tau option }

type ast = { loc : location ; node : node ; mutable tau : tau option }
and node =
  | Any
  | Pvar of pvar
  | Named of pvar * ast
  | Range of int * int
  | Int of Integer.t
  | Bool of bool

let node ~loc ?tau node = { loc ; node ; tau }

module Vmap = Map.Make(String)

type context = {
  typing : typing_context ;
  mutable value : bool ;
  mutable pvars : pvar Vmap.t ;
}

type pattern = ast
type value = ast

(* -------------------------------------------------------------------------- *)
(* --- Node Parsing                                                       --- *)
(* -------------------------------------------------------------------------- *)

let context typing = { typing ; value = false ; pvars = Vmap.empty }

let pvar ctxt ~loc x =
  try Vmap.find x ctxt.pvars with Not_found ->
    let pv = { vloc = loc ; vname = x ; vtau = None } in
    ctxt.pvars <- Vmap.add x pv ctxt.pvars ; pv

let pbound ctxt p =
  let loc = p.lexpr_loc in
  match p.lexpr_node with
  | PLconstant (IntConstant a) ->
    (try int_of_string a
     with Invalid_argument _ -> ctxt.typing.error loc "Invalid bound %S" a)
  | _ -> ctxt.typing.error loc "Invalid bound (int expected)"

let rec parse ctxt p =
  let loc = p.lexpr_loc in
  match p.lexpr_node with
  | PLvar "_" -> node ~loc Any
  | PLvar x -> node ~loc (Pvar (pvar ctxt ~loc x))
  | PLnamed(x,p) ->
    let pv = pvar ctxt ~loc x in
    let pn = parse ctxt p in
    node ~loc (Named(pv,pn))
  | PLapp("\\true",[],[]) -> node ~loc ~tau:Bool (Bool true)
  | PLapp("\\false",[],[]) -> node ~loc ~tau:Bool (Bool false)
  | PLconstant (IntConstant n) ->
    node ~loc ~tau:Int (Int (Integer.of_string n))
  | PLrange(Some a,Some b) when ctxt.value ->
    node ~loc ~tau:Int (Range(pbound ctxt a,pbound ctxt b))
  | _ ->
    ctxt.typing.error loc
      (if ctxt.value then "Invalid value" else "Invalid pattern")

let pa_pattern ctxt p = ctxt.value <- false ; parse ctxt p
let pa_value ctxt p = ctxt.value <- true ; parse ctxt p

(* -------------------------------------------------------------------------- *)
(* --- Pattern Lookup                                                     --- *)
(* -------------------------------------------------------------------------- *)

type lookup = {
  head: bool ;
  goal: bool ;
  hyps: bool ;
  pattern: pattern ;
}

(* -------------------------------------------------------------------------- *)
