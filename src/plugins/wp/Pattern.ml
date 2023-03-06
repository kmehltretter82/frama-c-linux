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

let (++) (a : location) (b : location) : location = (fst a,snd b)

type ast = { loc : location ; node : node ; mutable tau : tau option }
and node =
  | Any
  | Pvar of pvar
  | Named of pvar * node
  | Int of Integer.t
  | Bool of bool
  | Range of int * int
  | Call of Lang.lfun * node list
  | Add of node list
  | Mul of node list
  | Lt of node * node
  | Le of node * node
  | Eq of node * node

type context = typing_context
type pattern = ast
type value = ast

type lookup = {
  head: bool ;
  goal: bool ;
  hyps: bool ;
  pattern: pattern ;
}

let context ctxt = ctxt

let pa_pattern env p =
  env.error p.lexpr_loc "Invalid pattern"

let pa_value env p =
  env.error p.lexpr_loc "Invalid value"

(* -------------------------------------------------------------------------- *)
