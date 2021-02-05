(**************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2020                                               *)
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
  bhv_ensures: WpPropId.pred_info list ;
  bhv_exits: WpPropId.pred_info list ;
  bhv_post_assigns: WpPropId.assigns_full_info ;
  bhv_exit_assigns: WpPropId.assigns_full_info ;
}

let normalize_assumes kf ki h =
  let module L = NormAtLabels in
  let labels =
    match ki with
    | Kglobal -> L.labels_fct_pre
    | Kstmt s -> L.labels_stmt_pre kf s in
  L.preproc_annot labels h

let implies ?assumes p =
  match assumes with None -> p | Some h -> Logic_const.pimplies (h,p)

let normalize_pre kf ki bhv ?assumes ip =
  let module L = NormAtLabels in
  let labels =
    match ki with
    | Kglobal -> L.labels_fct_pre
    | Kstmt s -> L.labels_stmt_pre kf s in
  let id = WpPropId.mk_pre_id kf ki bhv ip in
  let p = L.preproc_annot labels ip.ip_content.tp_statement in
  id, implies ?assumes p

let normalize_post kf ki bhv tk ?assumes ip =
  let module L = NormAtLabels in
  let labels =
    match ki with
    | Kglobal -> L.labels_fct_post
    | Kstmt s -> L.labels_stmt_post kf s in
  let id = WpPropId.mk_post_id kf ki bhv (tk,ip) in
  let p = L.preproc_annot labels ip.ip_content.tp_statement in
  id , implies ?assumes p

let normalize_froms kf ki froms =
  let module L = NormAtLabels in
  let labels =
    match ki with
    | Kglobal -> L.labels_fct_assigns
    | Kstmt s -> L.labels_stmt_assigns kf s in
  L.preproc_assigns labels froms

let normalize_assigns kf ki has_exit bhv ~active = function
  | WritesAny ->
      WpPropId.empty_assigns_info, WpPropId.empty_assigns_info
  | Writes froms ->
      let make kf ki has_exit bhv tk froms =
        let aid = match ki with
          | Kglobal -> WpPropId.mk_fct_assigns_id kf has_exit bhv tk froms
          | Kstmt s -> WpPropId.mk_stmt_assigns_id kf s active bhv froms
        in match aid with
        | None -> WpPropId.empty_assigns_info
        | Some id ->
            let assigns = normalize_froms kf ki froms in
            let desc = match ki with
              | Kglobal -> WpPropId.mk_kf_assigns_desc assigns
              | Kstmt s -> WpPropId.mk_stmt_assigns_desc s assigns
            in  WpPropId.mk_assigns_info id desc
      in
      make kf ki has_exit bhv Normal froms,
      if has_exit
      then make kf ki has_exit bhv Exits froms
      else WpPropId.empty_assigns_info

let get_requires kf ki bhv =
  List.map (normalize_pre kf ki bhv) bhv.b_requires

let get_behavior kf ki ~exits ~active bhv =
  let pre_cond = normalize_pre kf ki bhv in
  let post_cond tk (kind,ip) =
    if kind = tk then Some (normalize_post kf ki bhv tk ip) else None in
  let p_asgn, e_asgn =
    normalize_assigns kf ki exits bhv ~active bhv.b_assigns
  in
  {
    bhv_assumes = List.map pre_cond bhv.b_assumes;
    bhv_requires = List.map pre_cond bhv.b_requires;
    bhv_ensures = List.filter_map (post_cond Normal) bhv.b_post_cond ;
    bhv_exits = List.filter_map (post_cond Exits) bhv.b_post_cond ;
    bhv_post_assigns = p_asgn ;
    bhv_exit_assigns = e_asgn ;
  }

(* -------------------------------------------------------------------------- *)
(* --- Side Behavior Requires                                             --- *)
(* -------------------------------------------------------------------------- *)

let get_assumes kf bhv =
  normalize_assumes kf Kglobal (Ast_info.behavior_assumes bhv)

let get_preconditions ~goal kf =
  List.map
    (fun bhv ->
       let p = Ast_info.behavior_precondition ~goal bhv in
       normalize_pre kf Kglobal bhv (Logic_const.new_predicate p)
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
(* --- Called Contract                                                    --- *)
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

type call_contract = {
  call_pre : WpPropId.pred_info list ;
  call_post : WpPropId.pred_info list ;
  call_exit : WpPropId.pred_info list ;
  call_assigns : Cil_types.assigns ;
}

let get_precond_at kf stmt (id,p) =
  let pi = WpPropId.property_of_id id in
  let pi_at = Statuses_by_call.precondition_at_call kf pi stmt in
  let id_at = WpPropId.mk_call_pre_id kf stmt pi pi_at in
  id_at , p

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

module CallContract = WpContext.StaticGenerator(Kernel_function)
    (struct
      type key = kernel_function
      type data = call_contract
      let name = "Wp.CfgAnnot.CallContract"
      let compile kf =
        let cpre : WpPropId.pred_info list ref = ref [] in
        let cpost : WpPropId.pred_info list ref = ref [] in
        let cexit : WpPropId.pred_info list ref = ref [] in
        let add c f x = c := (f x) :: !c in
        let behaviors = Annotations.behaviors kf in
        setup_preconditions kf ;
        List.iter
          begin fun bhv ->
            let assumes = get_assumes kf bhv in
            let mk_pre = normalize_pre kf Kglobal bhv ~assumes in
            let mk_post = normalize_post kf Kglobal bhv ~assumes in
            List.iter (add cpre @@ mk_pre) bhv.b_requires ;
            List.iter
              (fun (tk,ip) ->
                 add (if tk = Normal then cpost else cexit) (mk_post tk) ip
              ) bhv.b_post_cond ;
          end behaviors ;
        {
          call_pre = List.rev !cpre ;
          call_post = List.rev !cpost ;
          call_exit = List.rev !cexit ;
          call_assigns = assigns_upper_bound behaviors
        }
    end)

let get_call_contract = CallContract.get

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
        let labels = NormAtLabels.labels_assert_before ~kf stmt in
        let normalize_pred p = NormAtLabels.preproc_annot labels p in
        reverse_code_assertions @@
        Annotations.fold_code_annot
          begin fun _emitter ca l ->
            match ca.annot_content with
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

let get_code_assertions kf stmt = CodeAssertions.get (kf,stmt)

(* -------------------------------------------------------------------------- *)
(* --- Loop Invariants                                                    --- *)
(* -------------------------------------------------------------------------- *)

type loop_contract = {
  (* to be verified at loop entry *)
  loop_established: WpPropId.pred_info list;
  (* to be assumed for loop current *)
  loop_invariants: WpPropId.pred_info list;
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
          loop_assigns = [] ;
        }
    end)

let get_loop_contract kf stmt = LoopContract.get (kf,stmt)

(* -------------------------------------------------------------------------- *)
