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
  | Assoc of assoc * ast list
  | Binop of ast * binop * ast
  | Call of string * ast list
  | Times of Integer.t * ast
  | List of ast list
  | Field of ast * string
  | Get of ast * ast
  | Set of ast * ast * ast
and assoc = [ `Add | `Mul ]
and binop = [ `Div | `Mod | `Repeat | `Eq | `Lt | `Le | `Ne ]

let assoc op a b =
  let unroll = function Assoc(f,xs) when f = op -> xs | _ -> [a]
  in {
    loc = fst a.loc, snd b.loc ;
    value = Assoc(op,unroll a.value @ unroll b.value) ;
  }

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
  | PLtrue -> { loc ; value = Bool true }
  | PLfalse -> { loc ; value = Bool false }
  | PLconstant (IntConstant n) ->
    { loc ; value = Int (pinteger ctxt ~loc n) }
  | PLrange(Some a,Some b) when ctxt.value ->
    { loc ; value = Range(pbound ctxt a,pbound ctxt b) }
  | PLapp(lf,[],ps) ->
    { loc ; value = Call(lf,List.map (parse ctxt) ps) }
  | PLunop(Uminus,a) ->
    let a = parse ctxt a in
    { loc = a.loc ; value = Times(Integer.minus_one,a) }
  | PLbinop(a,Bmul,b) ->
    let a = parse ctxt a in
    let b = parse ctxt b in
    begin
      match a.value with
      | Int k -> { loc ; value = Times(k,b) }
      | _ -> assoc `Mul a b
    end
  | PLbinop(a,Bsub,b) ->
    let a = parse ctxt a in
    let b = parse ctxt b in
    let b = { loc = b.loc ; value = Times(Integer.minus_one,b) } in
    assoc `Add a b
  | PLbinop(a,Badd,b) -> assoc `Add (parse ctxt a) (parse ctxt b)
  | PLbinop(a,Bdiv,b) -> parse_binop ctxt ~loc `Div a b
  | PLbinop(a,Bmod,b) -> parse_binop ctxt ~loc `Mod a b
  | PLrel(a,Lt,b) -> parse_binop ctxt ~loc `Lt a b
  | PLrel(a,Le,b) -> parse_binop ctxt ~loc `Le a b
  | PLrel(a,Gt,b) -> parse_binop ctxt ~loc `Lt b a
  | PLrel(a,Ge,b) -> parse_binop ctxt ~loc `Le b a
  | PLrel(a,Eq,b) -> parse_binop ctxt ~loc `Eq a b
  | PLrel(a,Neq,b) -> parse_binop ctxt ~loc `Ne a b
  | PLempty -> { loc ; value = List [] }
  | PLlist ps -> { loc ; value = List (List.map (parse ctxt) ps) }
  | PLrepeat(p,n) -> parse_binop ctxt ~loc `Repeat p n
  | PLdot(a,fd) -> { loc ; value = Field(parse ctxt a,fd) }
  | PLarrget(a,b) ->
    begin
      match b.lexpr_node with
      | PLarrget(k,v) ->
        { loc ; value = Set(parse ctxt a,parse ctxt k,parse ctxt v) }
      | _ ->
        { loc ; value = Get(parse ctxt a,parse ctxt b) }
    end
  | _ ->
    ctxt.typing.error loc
      (if ctxt.value then "Invalid value" else "Invalid pattern")

and parse_binop ctxt ~loc op a b =
  { loc ; value = Binop(parse ctxt a,op,parse ctxt b) }

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

type sigma = Tactical.selection Vmap.t

(* -------------------------------------------------------------------------- *)
(* --- Value Extracting                                                   --- *)
(* -------------------------------------------------------------------------- *)

let error ~loc msg =
  Wp_parameters.logwith (fun _evt -> raise Not_found) ~source:(fst loc) msg

let getvar env (x : string loc) : Tactical.selection =
  try Vmap.find x.value env
  with Not_found ->
    error ~loc:x.loc "Pattern variable '%s' not bound" x.value

let rec select (env : sigma) (a : value) =
  let loc = a.loc in
  let cc = select env in
  match a.value with
  | Any ->  error ~loc "Pattern _ is not a value"
  | Pvar x -> getvar env x
  | Named (_,v) -> cc v
  | Range(a,b) -> Tactical.range a b
  | Int n -> Tactical.cint n
  | Bool b -> Tactical.compose (if b then "wp:true" else "wp:false") []
  | Assoc(op,vs) ->
    let op = match op with
      | `Add -> "wp:add"
      | `Mul -> "wp:mul"
    in Tactical.compose op (List.map (cc) vs)
  | Binop(a,op,b) ->
    let op = match op with
      | `Div -> "wp:div"
      | `Mod -> "wp:mod"
      | `Eq -> "wp:eq"
      | `Ne -> "wp:neq"
      | `Lt -> "wp:lt"
      | `Le -> "wp:leq"
      | `Repeat -> "wp:repeat"
    in compose env ~loc op [a;b]
  | Times(k,v) -> Tactical.compose "wp:mul" [Tactical.cint k;cc v]
  | Get(a,k) -> Tactical.compose "wp:get" [cc a;cc k]
  | Set(a,k,v) -> Tactical.compose "wp:set" [cc a;cc k;cc v]
  | List vs -> Tactical.compose "wp:list" (List.map cc vs)
  | Field(v,id) -> compose env ~loc ("fd:" ^ id) [v]
  | Call(id,vs) -> compose env ~loc ("lf:" ^ id) vs

and compose env ~loc id vs =
  match Tactical.compose id (List.map (select env) vs) with
  | Tactical.Empty -> error ~loc "Computer %S not found" id
  | result -> result

(* -------------------------------------------------------------------------- *)
