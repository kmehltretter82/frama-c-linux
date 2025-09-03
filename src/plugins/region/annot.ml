(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Cil_types

open Memory
open Logic

(* -------------------------------------------------------------------------- *)
(* ---  Utils                                                             --- *)
(* -------------------------------------------------------------------------- *)

module Vmap = Cil_datatype.Varinfo.Map

let iadd_term env t = ignore @@ add_term env t
let add_iterm env = function { it_content = t } -> add_term env t

let add_ipred env ip = add_predicate env ip.ip_content.tp_statement

(* -------------------------------------------------------------------------- *)
(* ---  Process Behaviors                                                 --- *)
(* -------------------------------------------------------------------------- *)

let iadd_from ~iscalled env (tgt,from) =
  let d = add_iterm env tgt in
  match from with
  | FromAny -> ()
  | From srcs ->
    if iscalled then
      let merge_from env a it =
        merge_domain a @@ add_iterm env it
      in ignore @@ List.fold_left (merge_from env) d srcs
    else
      List.iter (fun it -> ignore @@ add_iterm env it) srcs

let add_requires ~map ~kf ~ki ~bhv ~formal ~result ip =
  let property = Property.ip_of_requires kf ki bhv ip in
  add_ipred { map ; property ; formal ; result } ip

let add_assumes ~map ~kf ~ki ~bhv ~formal ~result ip =
  let property = Property.ip_of_assumes kf ki bhv ip in
  add_ipred { map ; property ; formal ; result } ip

let add_assigns ~iscalled ~map ~kf ~ki ~bhv ~formal ~result asgn =
  match asgn with
  | WritesAny -> ()
  | Writes ws ->
    let bhv = Property.Id_contract (Datatype.String.Set.empty,bhv) in
    let property = Option.get @@ Property.ip_of_assigns kf ki bhv asgn in
    let env = { map ; property ; formal ; result } in
    List.iter (iadd_from ~iscalled env) ws

let add_allocation ~map ~kf ~ki ~bhv ~formal ~result alloc =
  match alloc with
  | FreeAllocAny -> ()
  | FreeAlloc (its1, its2) ->
    let bhv = Property.Id_contract (Datatype.String.Set.empty,bhv) in
    let property = Option.get @@ Property.ip_of_allocation kf ki bhv alloc in
    let env = { map ; property ; formal ; result } in
    let add_alloc env it1 it2 =
      let d1 = add_iterm env it1 in
      let d2 = add_iterm env it2 in
      ignore @@ merge_domain d1 d2
    in
    List.iter2 (add_alloc env) its1 its2

let add_post_cond ~map ~kf ~ki ~bhv ~formal ~result cs =
  let property = Property.ip_of_behavior kf ki ~active:[] bhv in
  let add_pc (_,ip) = add_ipred { map ; property ; formal ; result } ip in
  List.iter add_pc cs

let rec add_extension ~kf ?stmt ?(formal=Vmap.empty) ~result map acsl =
  let extended_loc = match stmt with
    | None -> Property.ELContract kf
    | Some stmt -> Property.ELStmt (kf, stmt)
  in let property = Property.ip_of_extended extended_loc acsl in
  match acsl.ext_kind with
  | Ext_id _ ->
    if String.compare acsl.ext_plugin "region" != 0
    || String.compare acsl.ext_name "region" != 0
    then Options.warning "unhandled extension @[%s@]::@[%s@]@."
        acsl.ext_plugin acsl.ext_name
  | Ext_terms ts ->
    let env = { map ; property ; formal ; result } in
    List.iter (iadd_term env) ts
  | Ext_preds ps ->
    let env = { map ; property ; formal ; result } in
    List.iter (add_predicate env) ps
  | Ext_annot (_,acsls) ->
    List.iter (add_extension ~kf ?stmt ~formal ~result map) acsls


let add_behavior ~kf ~ki ?(formal=Vmap.empty) ~result ~iscalled map bhv =
  List.iter (add_requires ~map ~kf ~ki ~bhv ~formal ~result) bhv.b_requires ;
  List.iter (add_assumes ~map ~kf ~ki ~bhv ~formal ~result)  bhv.b_assumes  ;
  add_post_cond ~map ~kf ~ki ~bhv ~formal ~result            bhv.b_post_cond ;
  add_assigns ~iscalled ~map ~kf ~ki ~bhv ~formal ~result    bhv.b_assigns ;
  add_allocation ~map ~kf ~ki ~bhv ~formal ~result           bhv.b_allocation ;
  List.iter (add_extension ~kf ~formal ~result map)          bhv.b_extended

(* -------------------------------------------------------------------------- *)
(* ---  Process Code Annotation                                           --- *)
(* -------------------------------------------------------------------------- *)

let add_variant ~kf ~ki ?(formal=Vmap.empty) ~result map variant =
  let property = Property.ip_of_decreases kf ki variant in
  let env = { map ; property ; formal ; result } in
  let add_variant_relation rel =
    ignore @@ Memory.add_logic_info map rel ;
    (* ignore @@ Logic.add_logic_info_body env rel ; *)
  in
  Option.iter add_variant_relation @@ snd variant ;
  ignore @@ add_term env @@ fst variant

let add_spec ~kf ~ki ?(formal=Vmap.empty) ~result ~iscalled (map:map) (s:spec) =
  let p_term = Property.ip_terminates_of_spec kf ki s in
  let env_term op = { map ; property = Option.get op ; formal ; result } in
  Option.iter (add_ipred (env_term p_term)) s.spec_terminates ;
  Option.iter (add_variant ~kf ~ki ~formal ~result map) s.spec_variant ;
  List.iter (add_behavior ~iscalled ~kf ~ki ~formal ~result map) s.spec_behavior

(* -------------------------------------------------------------------------- *)
(* ---  Process Function Body                                             --- *)
(* -------------------------------------------------------------------------- *)

let add_code_annot ~kf ~stmt ?(formal=Vmap.empty) ~result ~iscalled map c =
  match c.annot_content with
  | AAssert (_,{ tp_statement = p }) ->
    let property = Property.ip_of_code_annot_single kf stmt c in
    let env = { map ; property ; formal ; result } in
    add_predicate env p
  | AStmtSpec (_,s) ->
    let ki = Cil_datatype.Kinstr.kinstr_of_opt_stmt (Some stmt) in
    add_spec ~iscalled ~kf ~ki ~formal ~result map s
  | AInvariant (_,_,{ tp_statement = p }) ->
    let property = Property.ip_of_code_annot_single kf stmt c in
    let env = { map ; property ; formal ; result } in
    add_predicate env p
  | AVariant v ->
    let ki = Cil_datatype.Kinstr.kinstr_of_opt_stmt (Some stmt) in
    add_variant ~kf ~ki ~formal ~result map v
  | AAssigns (_,WritesAny) -> ()
  | AAssigns (_,Writes asgn) ->
    let ki = Cil_datatype.Kinstr.kinstr_of_opt_stmt (Some stmt) in
    let property = Option.get @@ Property.ip_assigns_of_code_annot kf ki c in
    List.iter (iadd_from ~iscalled { map ; property ; formal ; result }) asgn
  | AAllocation (_,FreeAllocAny) -> ()
  | AAllocation (_,(FreeAlloc (its1,its2) as alloc)) ->
    if List.compare_lengths its1 its2 != 0 then
      Options.warning "FreeAlloc lengths not equal" ;
    let bol = Property.Id_loop c in
    let ki = Cil_datatype.Kinstr.kinstr_of_opt_stmt (Some stmt) in
    let property = Option.get @@ Property.ip_of_allocation kf ki bol alloc in
    let add_alloc env it1 it2 =
      let d1 = add_iterm env it1 in
      let d2 = add_iterm env it2 in
      ignore @@ merge_domain d1 d2
    in
    List.iter2 (add_alloc { map ; property ; formal ; result }) its1 its2
  | AExtended (_,_, acsl) ->
    add_extension ~kf ~stmt ~formal ~result map acsl
