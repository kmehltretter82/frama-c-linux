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
let iadd_iterm env t = ignore @@ add_iterm env t
let add_ipred env ip = add_predicate env ip.ip_content.tp_statement

(* -------------------------------------------------------------------------- *)
(* ---  Process Assigns (From)                                            --- *)
(* -------------------------------------------------------------------------- *)

let add_write env lv tgt =
  Memory.add_write tgt @@ Access.Term(env.property,lv)

let add_points_to env tgt = function
  | FromAny ->
    let loc = Property.location env.property in
    Options.abort ~source:(fst loc)
      "Missing \\from for pointer assignment"
  | From deps ->
    let domain =
      List.fold_left
        (fun d t -> merge_domain d (add_iterm env t))
        pure deps in
    match merge_points_to domain with
    | Some src -> Memory.add_points_to tgt src
    | None ->
      let loc = Property.location env.property in
      Options.abort ~source:(fst loc)
        "Missing pointer \\from for pointer assignment"

let add_writes_from env (lv : term_lval) ~(from:deps) =
  let ty,tgt = add_addr_lval env lv in
  if Ast_types.is_arithmetic ty then
    add_write env lv tgt
  else if Ast_types.is_fun_or_ptr ty then
    begin
      add_write env lv tgt ;
      add_points_to env tgt from ;
    end
  else
    Options.not_yet_implemented "assigns to type (%a)" Printer.pp_typ ty

let rec add_assigns_from env tgt ~from =
  match tgt.term_node with
  | TLval lv -> add_writes_from env lv ~from
  | Tat(t,_) -> add_assigns_from env ~from t
  | Tunion ts -> List.iter (add_assigns_from env ~from) ts
  | Tinter ts ->
    Options.warning "assigns intersection treated as union" ;
    List.iter (add_assigns_from env ~from) ts
  | Tcomprehension _ -> Options.not_yet_implemented "assigns comprehension"
  | Tlet _ -> Options.not_yet_implemented "let-assigns"
  | Tif (c,tt,te) ->
    Options.warning ~source:(fst c.term_loc) "ignored assigns-condition" ;
    add_assigns_from env tt ~from ;
    add_assigns_from env te ~from ;
  | TConst _ | TSizeOf _ | TSizeOfE _ | TAlignOf _ | TAlignOfE _
  | TUnOp _ | TBinOp _ | TCast _ | TAddrOf _ | TStartOf _
  | Tapp _ | Tlambda _ | TDataCons _
  | Tbase_addr _ | Toffset (_, _) | Tblock_length _ | Tnull
  | TUpdate _ | Ttypeof _ | Ttype _ | Tempty_set | Trange _ ->
    Options.warning ~source:(fst tgt.term_loc)
      "Non-assignable term (skipped)@ (%a)"
      Printer.pp_term tgt

let add_assigns ~iscalled env = function
  | WritesAny ->
    let loc = Property.location env.property in
    Options.abort ~source:(fst loc) "unprecise assigns are not supported"
  | Writes ws ->
    if iscalled then
      List.iter (fun (t,from) -> add_assigns_from env t.it_content ~from) ws
    else
      List.iter (fun (t,_) -> iadd_iterm env t) ws

(* -------------------------------------------------------------------------- *)
(* ---  Process Behaviors                                                 --- *)
(* -------------------------------------------------------------------------- *)

let add_requires ~map ~kf ~ki ~bhv ~formals ~result ip =
  let property = Property.ip_of_requires kf ki bhv ip in
  add_ipred { map ; property ; formals ; result } ip

let add_assumes ~map ~kf ~ki ~bhv ~formals ~result ip =
  let property = Property.ip_of_assumes kf ki bhv ip in
  add_ipred { map ; property ; formals ; result } ip

let add_bassigns ~iscalled ~map ~kf ~ki ~bhv ~formals ~result asgn =
  let bhv = Property.Id_contract (Datatype.String.Set.empty,bhv) in
  let property = Option.get @@ Property.ip_of_assigns kf ki bhv asgn in
  let env = { map ; property ; formals ; result } in
  add_assigns ~iscalled env asgn

let add_allocation ~map ~kf ~ki ~bhv ~formals ~result alloc =
  match alloc with
  | FreeAllocAny -> ()
  | FreeAlloc (its1, its2) ->
    let bhv = Property.Id_contract (Datatype.String.Set.empty,bhv) in
    let property = Option.get @@ Property.ip_of_allocation kf ki bhv alloc in
    let env = { map ; property ; formals ; result } in
    let add_alloc env it1 it2 =
      let d1 = add_iterm env it1 in
      let d2 = add_iterm env it2 in
      ignore @@ merge_domain d1 d2
    in
    List.iter2 (add_alloc env) its1 its2

let add_post_cond ~map ~kf ~ki ~bhv ~formals ~result cs =
  let property = Property.ip_of_behavior kf ki ~active:[] bhv in
  let add_pc (_,ip) = add_ipred { map ; property ; formals ; result } ip in
  List.iter add_pc cs

let rec add_extension ~kf ~ki ~formals ~result map acsl =
  let extended_loc =
    match ki with
    | Kglobal -> Property.ELContract kf
    | Kstmt stmt -> Property.ELStmt (kf, stmt)
  in let property = Property.ip_of_extended extended_loc acsl in
  match acsl.ext_kind with
  | Ext_id _ ->
    if acsl.ext_plugin <> "region" then
      Options.warning "unhandled extension @[%s@]::@[%s@]@."
        acsl.ext_plugin acsl.ext_name
  | Ext_terms ts ->
    let env = { map ; property ; formals ; result } in
    List.iter (iadd_term env) ts
  | Ext_preds ps ->
    let env = { map ; property ; formals ; result } in
    List.iter (add_predicate env) ps
  | Ext_annot (_,acsls) ->
    List.iter (add_extension ~kf ~ki ~formals ~result map) acsls


let add_behavior ~kf ~ki ~formals ~result ~iscalled map bhv =
  begin
    List.iter (add_requires ~map ~kf ~ki ~bhv ~formals ~result) bhv.b_requires ;
    List.iter (add_assumes ~map ~kf ~ki ~bhv ~formals ~result) bhv.b_assumes ;
    add_post_cond ~map ~kf ~ki ~bhv ~formals ~result bhv.b_post_cond ;
    add_bassigns ~iscalled ~map ~kf ~ki ~bhv ~formals ~result bhv.b_assigns ;
    add_allocation ~map ~kf ~ki ~bhv ~formals ~result bhv.b_allocation ;
    List.iter (add_extension ~kf ~ki ~formals ~result map) bhv.b_extended ;
  end

(* -------------------------------------------------------------------------- *)
(* ---  Process Code Annotation                                           --- *)
(* -------------------------------------------------------------------------- *)

let add_variant ~kf ~ki ~formals ~result map variant =
  let property = Property.ip_of_decreases kf ki variant in
  let env = { map ; property ; formals ; result } in
  ignore @@ add_term env @@ fst variant

let add_spec ~kf ~ki ~formals ~result ~iscalled (map:map) (s:spec) =
  let p_term = Property.ip_terminates_of_spec kf ki s in
  let env_term op = { map ; property = Option.get op ; formals ; result } in
  Option.iter (add_ipred (env_term p_term)) s.spec_terminates ;
  Option.iter (add_variant ~kf ~ki ~formals ~result map) s.spec_variant ;
  List.iter (add_behavior ~iscalled ~kf ~ki ~formals ~result map) s.spec_behavior

(* -------------------------------------------------------------------------- *)
(* ---  Process Code Annotations                                          --- *)
(* -------------------------------------------------------------------------- *)

let add_code_annot ~kf ~stmt ~formals ~result ~iscalled map c =
  match c.annot_content with
  | AAssert (_,{ tp_statement = p }) ->
    let property = Property.ip_of_code_annot_single kf stmt c in
    let env = { map ; property ; formals ; result } in
    add_predicate env p
  | AStmtSpec (_,s) ->
    let ki = Cil_datatype.Kinstr.kinstr_of_opt_stmt (Some stmt) in
    add_spec ~iscalled ~kf ~ki ~formals ~result map s
  | AInvariant (_,_,{ tp_statement = p }) ->
    let property = Property.ip_of_code_annot_single kf stmt c in
    let env = { map ; property ; formals ; result } in
    add_predicate env p
  | AVariant v ->
    let ki = Cil_datatype.Kinstr.kinstr_of_opt_stmt (Some stmt) in
    add_variant ~kf ~ki ~formals ~result map v
  | AAssigns (_,asgn) ->
    let property = Property.ip_of_code_annot_single kf stmt c in
    let env = { map ; property ; formals ; result } in
    add_assigns ~iscalled env asgn
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
    List.iter2 (add_alloc { map ; property ; formals ; result }) its1 its2
  | AExtended (_,_, acsl) ->
    let ki = Cil_datatype.Kinstr.kinstr_of_opt_stmt (Some stmt) in
    add_extension ~kf ~ki ~formals ~result map acsl
