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

(* -------------------------------------------------------------------------- *)
(* --- Pattern Engine                                                     --- *)
(* -------------------------------------------------------------------------- *)

type 'a loc = { loc : location ; value : 'a }

type pvar = string loc
type ast = node loc
and node =
  | Any
  | Pvar of pvar
  | Named of pvar * ast
  | Range of int * int
  | Int of Integer.t
  | Bool of bool
  | Call of string * ast list

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

let pint ctxt ~loc a =
  try int_of_string a
  with _ -> ctxt.typing.error loc "Invalid int %S" a

let pinteger ctxt ~loc a =
  try Integer.of_string a
  with _ -> ctxt.typing.error loc "Invalid integer %S" a

let pvar ctxt ~loc x =
  try Vmap.find x ctxt.pvars with Not_found ->
    if ctxt.value then
      ctxt.typing.error loc "Unknown pattern variable '%s'" x
    else
      let pv = { loc ; value = x } in
      ctxt.pvars <- Vmap.add x pv ctxt.pvars ; pv

let pbound ctxt p =
  let loc = p.lexpr_loc in
  match p.lexpr_node with
  | PLconstant (IntConstant a) -> pint ctxt ~loc a
  | _ -> ctxt.typing.error loc "Invalid bound (int expected)"

let rec parse ctxt p =
  let loc = p.lexpr_loc in
  match p.lexpr_node with
  | PLvar "_" when ctxt.value -> { loc ; value = Any }
  | PLvar x -> { loc ; value = Pvar (pvar ctxt ~loc x) }
  | PLnamed(x,p) ->
    let pv = pvar ctxt ~loc x in
    let pn = parse ctxt p in
    { loc ; value = Named(pv,pn) }
  | PLapp("\\true",[],[]) -> { loc ; value = Bool true }
  | PLapp("\\false",[],[]) -> { loc ; value = Bool false }
  | PLconstant (IntConstant n) ->
    { loc ; value = Int (pinteger ctxt ~loc n) }
  | PLrange(Some a,Some b) when ctxt.value ->
    { loc ; value = Range(pbound ctxt a,pbound ctxt b) }
  | PLapp(lf,[],ps) ->
    { loc ; value = Call(lf,List.map (parse ctxt) ps) }
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
