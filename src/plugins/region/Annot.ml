(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2025                                               *)
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

open Memory
open LDomain
open Logic

(* -------------------------------------------------------------------------- *)
(* ---  Utils                                                             --- *)
(* -------------------------------------------------------------------------- *)

module Vmap = Cil_datatype.Varinfo.Map

let iadd_iterm env = function { it_content = t } -> ignore @@ add_term env t

let add_ipred env ip = add_predicate env ip.ip_content.tp_statement

(* -------------------------------------------------------------------------- *)
(* ---  Process Behaviors                                                 --- *)
(* -------------------------------------------------------------------------- *)

let iadd_from env (it,from) = match from with
  | FromAny -> iadd_iterm env it
  | From its -> List.iter (iadd_iterm env) its ; iadd_iterm env it

let add_requires map kf ki b formal ip =
  let property = Property.ip_of_requires kf ki b ip in
  add_ipred { map ; property ; formal ; result = pure } ip

let add_assumes map kf ki b formal ip =
  let property = Property.ip_of_assumes kf ki b ip in
  add_ipred { map ; property ; formal ; result = pure } ip

let add_assigns map kf ki b formal asgn =
  match asgn with
  | WritesAny -> ()
  | Writes ws ->
    let bhv = Property.Id_contract (Datatype.String.Set.empty,b) in
    let property = Option.get @@ Property.ip_of_assigns kf ki bhv asgn in
    let env = { map ; property ; formal ; result = pure } in
    List.iter (iadd_from env) ws

let add_allocation map kf ki b formal alloc =
  match alloc with
  | FreeAllocAny -> ()
  | FreeAlloc (its1, its2) ->
    let bhv = Property.Id_contract (Datatype.String.Set.empty,b) in
    let property = Option.get @@ Property.ip_of_allocation kf ki bhv alloc in
    let env = { map ; property ; formal ; result = pure } in
    List.iter (iadd_iterm env) its1 ;
    List.iter (iadd_iterm env) its2

let add_post_cond m kf ki b formal cs =
  let add_post_cond map property (_,ip) =
    add_ipred { map ; property ; formal ; result = pure } ip
  in
  let post_conds = Property.ip_post_cond_of_behavior kf ki ~active:[] b in
  List.iter2 (add_post_cond m) post_conds cs

let add_extension _ = ()

let add_behavior ~kf ~ki ?formal (m:map) (b:behavior) =
  let formal = Option.value ~default:Vmap.empty formal in
  List.iter (add_requires m kf ki b formal) b.b_requires ;
  List.iter (add_assumes m kf ki b formal)  b.b_assumes  ;
  add_post_cond m kf ki b formal            b.b_post_cond ;
  add_assigns m kf ki b formal              b.b_assigns ;
  add_allocation m kf ki b formal           b.b_allocation ;
  List.iter (add_extension)                 b.b_extended

(* -------------------------------------------------------------------------- *)
(* ---  Process Code Annotation                                           --- *)
(* -------------------------------------------------------------------------- *)

let add_variant ~kf ~ki ?formal map variant =
  let property = Property.ip_of_decreases kf ki variant in
  let formal = Option.value ~default:Vmap.empty formal in
  let env = { map ; property ; formal ; result = pure } in
  let add_variant_relation rel =
    ignore @@ Memory.add_logic_info map rel ;
    ignore @@ Logic.add_logic_info_body env rel ;
  in
  Option.iter add_variant_relation @@ snd variant ;
  ignore @@ add_term env @@ fst variant

let add_spec ~kf ~ki ?formal (map:map) (s:spec) =
  let p_term = Property.ip_terminates_of_spec kf ki s in
  let formal = Option.value ~default:Vmap.empty formal in
  let env_term op = { map ; property = Option.get op ; formal ; result = pure } in
  Option.iter (add_ipred (env_term p_term)) s.spec_terminates ;
  Option.iter (add_variant ~kf ~ki ~formal map) s.spec_variant ;
  List.iter (add_behavior ~kf ~ki ~formal map) s.spec_behavior

let add_code_annot ~kf ~ki ~stmt ?formal (map:map) (c:code_annotation) =
  let formal = Option.value ~default:Vmap.empty formal in
  match c.annot_content with
  | AAssert (_,{ tp_statement = p }) ->
    let property = Property.ip_of_code_annot_single kf stmt c in
    let env = { map ; property ; formal ; result = pure } in
    add_predicate env p
  | AStmtSpec (_,s) -> add_spec ~kf ~ki ~formal map s
  | AInvariant (_,_,{ tp_statement = p }) ->
    let property = Property.ip_of_code_annot_single kf stmt c in
    let env = { map ; property ; formal ; result = pure } in
    add_predicate env p
  | AVariant v -> add_variant ~kf ~ki ~formal map v
  | AAssigns (_,WritesAny) -> ()
  | AAssigns (_,Writes asgn) ->
    let property = Option.get @@ Property.ip_assigns_of_code_annot kf ki c in
    List.iter (iadd_from { map ; property ; formal ; result = pure }) asgn
  | AAllocation (_,FreeAllocAny) -> ()
  | AAllocation (_,(FreeAlloc (its1,its2) as alloc)) ->
    let bol = Property.Id_loop c in
    let property = Option.get @@ Property.ip_of_allocation kf ki bol alloc in
    List.iter (iadd_iterm { map ; property ; formal ; result = pure }) its1 ;
    List.iter (iadd_iterm { map ; property ; formal ; result = pure }) its2
  | AExtended (_,_,_) -> assert false


(* let add_code_annot ... = ... *)
(* let add_spec ... = ... *)
(* let add_variant ... = ... *)
(* ===> utiliser un visiteur // nope
*)
