(**************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2021                                               *)
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

open Cil_types

(* -------------------------------------------------------------------------- *)
(* --- Smoke Tests                                                        --- *)
(* -------------------------------------------------------------------------- *)

let smoke kf ~id ?doomed ?unreachable () =
  WpPropId.mk_smoke kf ~id ?doomed ?unreachable () , Logic_const.pfalse

let get_unreachable kf stmt =
  WpPropId.mk_smoke kf ~id:"unreachabled" ~unreachable:stmt ()

(* -------------------------------------------------------------------------- *)
(* --- Memoization                                                        --- *)
(* -------------------------------------------------------------------------- *)

module CodeKey =
struct
  type t = kernel_function * stmt
  let compare (a:t) (b:t) = Stdlib.compare (snd a).sid (snd b).sid
  let pretty fmt (a:t) = Format.fprintf fmt "s%d" (snd a).sid
end

(* -------------------------------------------------------------------------- *)
(* --- Property Accessors : Behaviors                                     --- *)
(* -------------------------------------------------------------------------- *)

type behavior = {
  bhv_assumes: WpPropId.pred_info list ;
  bhv_requires: WpPropId.pred_info list ;
  bhv_smokes: WpPropId.pred_info list ;
  bhv_ensures: WpPropId.pred_info list ;
  bhv_exits: WpPropId.pred_info list ;
  bhv_post_assigns: WpPropId.assigns_full_info ;
  bhv_exit_assigns: WpPropId.assigns_full_info ;
}

let normalize_assumes h =
  let module L = NormAtLabels in
  let labels = L.labels_fct_pre in
  L.preproc_annot labels h

let implies ?assumes p =
  match assumes with None -> p | Some h -> Logic_const.pimplies (h,p)

let filter ~goal ip =
  if goal
  then Logic_utils.verify_predicate ip.ip_content.tp_kind
  else Logic_utils.use_predicate ip.ip_content.tp_kind

let normalize_pre ~goal kf bhv ?assumes ip =
  if filter ~goal ip then
    let module L = NormAtLabels in
    let labels = L.labels_fct_pre in
    let id = WpPropId.mk_pre_id kf Kglobal bhv ip in
    let p = L.preproc_annot labels ip.ip_content.tp_statement in
    Some (id, implies ?assumes p)
  else None

let normalize_post ~goal kf bhv tk ?assumes (itk,ip) =
  if tk = itk && filter ~goal ip then
    let module L = NormAtLabels in
    let labels = L.labels_fct_post ~exit:(tk=Exits) in
    let id = WpPropId.mk_post_id kf Kglobal bhv (tk,ip) in
    let p = L.preproc_annot labels ip.ip_content.tp_statement in
    Some (id , implies ?assumes p)
  else None

let normalize_froms tk froms =
  let module L = NormAtLabels in
  let labels = L.labels_fct_assigns ~exit:(tk=Exits) in
  L.preproc_assigns labels froms

let normalize_fct_assigns kf ~exits bhv = function
  | WritesAny ->
      WpPropId.empty_assigns_info, WpPropId.empty_assigns_info
  | Writes froms ->
      let make tk =
        match WpPropId.mk_fct_assigns_id kf exits bhv tk froms with
        | None -> WpPropId.empty_assigns_info
        | Some id ->
            let assigns = normalize_froms tk froms in
            let desc = WpPropId.mk_kf_assigns_desc assigns in
            WpPropId.mk_assigns_info id desc
      in
      make Normal,
      if exits then make Exits else WpPropId.empty_assigns_info

let get_behavior_goals kf ?(smoking=false) ?(exits=false) bhv =
  let pre_cond = normalize_pre ~goal:false kf bhv in
  let post_cond = normalize_post ~goal:true kf bhv in
  let p_asgn, e_asgn = normalize_fct_assigns kf ~exits bhv bhv.b_assigns in
  let smokes =
    if smoking && bhv.b_requires <> [] then
      let bname =
        if Cil.is_default_behavior bhv then "default" else bhv.b_name in
      let id = bname ^ "_requires" in
      let doomed = Property.ip_requires_of_behavior kf Kglobal bhv in
      [smoke kf ~id ~doomed ()]
    else []
  in
  {
    bhv_assumes = List.filter_map pre_cond bhv.b_assumes;
    bhv_requires = List.filter_map pre_cond bhv.b_requires;
    bhv_ensures = List.filter_map (post_cond Normal) bhv.b_post_cond ;
    bhv_exits = List.filter_map (post_cond Exits) bhv.b_post_cond ;
    bhv_post_assigns = p_asgn ;
    bhv_exit_assigns = e_asgn ;
    bhv_smokes = smokes;
  }

(* -------------------------------------------------------------------------- *)
(* --- Side Behavior Requires                                             --- *)
(* -------------------------------------------------------------------------- *)

let get_requires ~goal kf bhv =
  List.filter_map (normalize_pre ~goal kf bhv) bhv.b_requires

let get_preconditions ~goal kf =
  let module L = NormAtLabels in
  let mk_pre = L.preproc_annot L.labels_fct_pre in
  List.map
    (fun bhv ->
       let p = Ast_info.behavior_precondition ~goal bhv in
       let ip = Logic_const.new_predicate p in
       WpPropId.mk_pre_id kf Kglobal bhv ip,  mk_pre p
    ) (Annotations.behaviors kf)

let get_complete_behaviors kf =
  let spec = Annotations.funspec kf in
  let module L = NormAtLabels in
  List.map
    (fun bs ->
       WpPropId.mk_compl_bhv_id (kf,Kglobal,[],bs) ,
       L.preproc_annot L.labels_fct_pre @@ Ast_info.complete_behaviors spec bs
    ) spec.spec_complete_behaviors

let get_disjoint_behaviors kf =
  let spec = Annotations.funspec kf in
  let module L = NormAtLabels in
  List.map
    (fun bs ->
       WpPropId.mk_disj_bhv_id (kf,Kglobal,[],bs) ,
       L.preproc_annot L.labels_fct_pre @@ Ast_info.disjoint_behaviors spec bs
    ) spec.spec_disjoint_behaviors

(* -------------------------------------------------------------------------- *)
(* --- Contracts                                                          --- *)
(* -------------------------------------------------------------------------- *)

type contract = {
  contract_cond : WpPropId.pred_info list ;
  contract_hpre : WpPropId.pred_info list ;
  contract_post : WpPropId.pred_info list ;
  contract_exit : WpPropId.pred_info list ;
  contract_smoke : WpPropId.pred_info list ;
  contract_assigns : Cil_types.assigns ;
}

let assigns_upper_bound behaviors =
  let collect_assigns (def, assigns) bhv =
    (* Default behavior prevails *)
    if Cil.is_default_behavior bhv then Some bhv.b_assigns, None
    else if Option.is_some def then def, None
    else begin
      (* Note that here, def is None *)
      match assigns, bhv.b_assigns with
      | None, a -> None, Some a
      | Some WritesAny, _ | Some _, WritesAny -> None, Some WritesAny
      | Some (Writes a), Writes b -> None, Some (Writes (a @ b))
    end
  in
  match List.fold_left collect_assigns (None, None) behaviors with
  | Some a, _ -> a (* default behavior first *)
  | _, Some a -> a (* else combined behaviors *)
  | _ -> WritesAny

(* -------------------------------------------------------------------------- *)
(* --- Call Contracts                                                     --- *)
(* -------------------------------------------------------------------------- *)

(*TODO: put it in Status_by_call ? *)
module AllPrecondStatus =
  State_builder.Hashtbl(Kernel_function.Hashtbl)(Datatype.Unit)
    (struct
      let name = "Wp.CfgAnnot.AllPrecondStatus"
      let dependencies = [Ast.self]
      let size = 32
    end)

let setup_preconditions kf =
  if not (AllPrecondStatus.mem kf) then
    begin
      AllPrecondStatus.add kf () ;
      Statuses_by_call.setup_all_preconditions_proxies kf ;
    end

let get_precond_at kf stmt (id,p) =
  let pi = WpPropId.property_of_id id in
  let pi_at = Statuses_by_call.precondition_at_call kf pi stmt in
  let id_at = WpPropId.mk_call_pre_id kf stmt pi pi_at in
  id_at , p

module CallContract = WpContext.StaticGenerator(Kernel_function)
    (struct
      type key = kernel_function
      type data = contract
      let name = "Wp.CfgAnnot.CallContract"
      let compile kf =
        let wcond : WpPropId.pred_info list ref = ref [] in
        let whpre : WpPropId.pred_info list ref = ref [] in
        let wpost : WpPropId.pred_info list ref = ref [] in
        let wexit : WpPropId.pred_info list ref = ref [] in
        let add w f x = match f x with Some y -> w := y :: !w | None -> () in
        let behaviors = Annotations.behaviors kf in
        setup_preconditions kf ;
        List.iter
          begin fun bhv ->
            let assumes = normalize_assumes (Ast_info.behavior_assumes bhv) in
            let mk_cond = normalize_pre ~goal:true kf bhv ~assumes in
            let mk_hpre = normalize_pre ~goal:false kf bhv ~assumes in
            let mk_post = normalize_post ~goal:false kf bhv ~assumes in
            List.iter (add wcond @@ mk_cond) bhv.b_requires ;
            List.iter (add whpre @@ mk_hpre) bhv.b_requires ;
            List.iter (add wpost @@ mk_post Normal) bhv.b_post_cond ;
            List.iter (add wexit @@ mk_post Exits) bhv.b_post_cond ;
          end behaviors ;
        let assigns = match assigns_upper_bound behaviors with
          | WritesAny -> WritesAny
          | Writes froms -> Writes (normalize_froms Normal froms)
        in
        {
          contract_cond = List.rev !wcond ;
          contract_hpre = List.rev !whpre ;
          contract_post = List.rev !wpost ;
          contract_exit = List.rev !wexit ;
          contract_smoke = [] ;
          contract_assigns = assigns
        }
    end)

let get_call_contract ?smoking kf stmt =
  let cc = CallContract.get kf in
  let preconds = List.map (get_precond_at kf stmt) cc.contract_cond in
  match smoking with
  | None ->
      { cc with contract_cond = preconds }
  | Some s ->
      let g = smoke kf ~id:"dead_call" ~unreachable:s () in
      { cc with contract_cond = preconds ; contract_smoke = [ g ] }

(* -------------------------------------------------------------------------- *)
(* --- Assembly Code                                                      --- *)
(* -------------------------------------------------------------------------- *)

let is_assembly stmt =
  match stmt.skind with
  | Instr (Asm _) -> true
  | _ -> false

let get_stmt_assigns kf stmt =
  let asgn =
    Annotations.fold_code_annot
      begin fun _emitter ca l ->
        match ca.annot_content with
        | AStmtSpec(fors,s) ->
            List.fold_left
              (fun l bhv ->
                 match bhv.b_assigns with
                 | WritesAny -> l
                 | Writes froms ->
                     let module L = NormAtLabels in
                     let labels = L.labels_stmt_assigns ~kf stmt in
                     match
                       WpPropId.mk_stmt_assigns_id kf stmt fors bhv froms
                     with
                     | None -> l
                     | Some id ->
                         let froms = L.preproc_assigns labels froms in
                         let desc = WpPropId.mk_stmt_assigns_desc stmt froms in
                         WpPropId.mk_assigns_info id desc :: l
              ) l s.spec_behavior
        | _ -> l
      end stmt []
  in if asgn = [] then [WpPropId.empty_assigns_info] else asgn

(* -------------------------------------------------------------------------- *)
(* --- Code Assertions                                                    --- *)
(* -------------------------------------------------------------------------- *)

type code_assertions = {
  code_admitted: WpPropId.pred_info list ;
  code_verified: WpPropId.pred_info list ;
}

let reverse_code_assertions a = {
  code_admitted = List.rev a.code_admitted ;
  code_verified = List.rev a.code_verified ;
}

module CodeAssertions = WpContext.StaticGenerator(CodeKey)
    (struct
      type key = CodeKey.t
      type data = code_assertions
      let name = "Wp.CfgAnnot.CodeAssertions"
      let compile (kf,stmt) =
        let labels = NormAtLabels.labels_assert ~kf stmt in
        let normalize_pred p = NormAtLabels.preproc_annot labels p in
        reverse_code_assertions @@
        Annotations.fold_code_annot
          begin fun _emitter ca l ->
            match ca.annot_content with
            | AStmtSpec _ when not @@ is_assembly stmt ->
                let source = fst (Cil_datatype.Stmt.loc stmt) in
                Wp_parameters.warning ~once:true ~source
                  "Statement specifications not yet supported (skipped)." ; l
            | AInvariant(_,false,_) ->
                let source = fst (Cil_datatype.Stmt.loc stmt) in
                Wp_parameters.warning ~once:true ~source
                  "Generalized invariant not yet supported (skipped)." ; l
            | AAssert(_,a) ->
                let p =
                  WpPropId.mk_assert_id kf stmt ca ,
                  normalize_pred a.tp_statement in
                let admit = Logic_utils.use_predicate a.tp_kind in
                let verif = Logic_utils.verify_predicate a.tp_kind in
                let use flag p ps = if flag then p::ps else ps in
                {
                  code_admitted = use admit p l.code_admitted ;
                  code_verified = use verif p l.code_verified ;
                }
            | _ -> l
          end stmt {
          code_admitted = [];
          code_verified = [];
        }
    end)

let get_code_assertions ?(smoking=false) kf stmt =
  let ca = CodeAssertions.get (kf,stmt) in
  if smoking then
    let s = smoke kf ~id:"dead_code" ~unreachable:stmt () in
    { ca with code_verified = s :: ca.code_verified }
  else ca

(* -------------------------------------------------------------------------- *)
(* --- Loop Invariants                                                    --- *)
(* -------------------------------------------------------------------------- *)

type loop_contract = {
  (* to be verified at loop entry *)
  loop_established: WpPropId.pred_info list;
  (* to be assumed for loop current *)
  loop_invariants: WpPropId.pred_info list;
  (* to be proved after loop invariants *)
  loop_smoke: WpPropId.pred_info list;
  (* to be verified after loop body *)
  loop_preserved: WpPropId.pred_info list;
  (* assigned by loop body *)
  loop_assigns: WpPropId.assigns_full_info list;
}

let reverse_loop_contract l = {
  loop_established = List.rev l.loop_established ;
  loop_invariants = List.rev l.loop_invariants ;
  loop_preserved = List.rev l.loop_preserved ;
  loop_assigns = List.rev l.loop_assigns ;
  loop_smoke = List.rev l.loop_smoke ;
}

let default_assigns stmt l =
  { l with
    loop_assigns =
      if l.loop_assigns <> [] then l.loop_assigns
      else [WpPropId.mk_loop_any_assigns_info stmt] }

module LoopContract = WpContext.StaticGenerator(CodeKey)
    (struct
      type key = CodeKey.t
      type data = loop_contract
      let name = "Wp.CfgAnnot.LoopContract"
      let compile (kf,stmt) =
        let labels = NormAtLabels.labels_loop stmt in
        let normalize_pred p = NormAtLabels.preproc_annot labels p in
        let normalize_annot (i,p) = i, normalize_pred p in
        let normalize_assigns w = NormAtLabels.preproc_assigns labels w in
        default_assigns stmt @@
        reverse_loop_contract @@
        Annotations.fold_code_annot
          begin fun _emitter ca l ->
            match ca.annot_content with
            | AInvariant(_,true,inv) ->
                let p = normalize_pred inv.tp_statement in
                let g_hyp = WpPropId.mk_inv_hyp_id kf stmt ca in
                let g_est, g_ind = WpPropId.mk_loop_inv kf stmt ca in
                let admit = Logic_utils.use_predicate inv.tp_kind in
                let verif = Logic_utils.verify_predicate inv.tp_kind in
                let use flag id p ps = if flag then (id,p) :: ps else ps in
                { l with
                  loop_established = use verif g_est p l.loop_established ;
                  loop_invariants  = use admit g_hyp p l.loop_invariants ;
                  loop_preserved   = use verif g_ind p l.loop_preserved ;
                }
            | AVariant(term, None) ->
                let vpos , vdec =
                  WpStrategy.mk_variant_properties kf stmt ca term in
                { l with loop_preserved =
                           normalize_annot vdec ::
                           normalize_annot vpos ::
                           l.loop_preserved }
            | AAssigns(_,WritesAny) ->
                let asgn = WpPropId.mk_loop_any_assigns_info stmt in
                { l with loop_assigns = asgn :: l.loop_assigns }
            | AAssigns(_,Writes w) ->
                begin match WpPropId.mk_loop_assigns_id kf stmt ca w with
                  | None -> l (* shall not occur *)
                  | Some id ->
                      let w = normalize_assigns w in
                      let a = WpPropId.mk_loop_assigns_desc stmt w in
                      let asgn = WpPropId.mk_assigns_info id a in
                      { l with loop_assigns = asgn :: l.loop_assigns }
                end
            | _ -> l
          end stmt {
          loop_established = [] ;
          loop_invariants = [] ;
          loop_preserved = [] ;
          loop_smoke = [] ;
          loop_assigns = [] ;
        }
    end)

let get_loop_contract ?(smoking=false) kf stmt =
  let lc = LoopContract.get (kf,stmt) in
  if smoking && not (WpReached.is_dead_code stmt) then
    let g = smoke kf ~id:"dead_loop" ~unreachable:stmt () in
    { lc with loop_smoke = g :: lc.loop_smoke }
  else lc

(* -------------------------------------------------------------------------- *)
(* --- Clear Tablesnts                                                    --- *)
(* -------------------------------------------------------------------------- *)

let clear () =
  CallContract.clear () ;
  LoopContract.clear () ;
  CodeAssertions.clear ()

(* -------------------------------------------------------------------------- *)
