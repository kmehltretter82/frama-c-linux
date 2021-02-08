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
open Cil_datatype

(* -------------------------------------------------------------------------- *)
(* --- Automata Helpers                                                   --- *)
(* -------------------------------------------------------------------------- *)

module WpLog = Wp_parameters
module Kf = Kernel_function
module Cfg = Interpreted_automata
module G = Cfg.G
module V = Cfg.Vertex
module Vhash = V.Hashtbl
type vertex = Cfg.vertex
type assigns = WpPropId.assigns_full_info

(* -------------------------------------------------------------------------- *)
(* --- Calculus Modes (passes)                                            --- *)
(* -------------------------------------------------------------------------- *)

type mode = {
  kf: kernel_function;
  bhv : funbehavior ;
  infos : CfgInfos.t ;
}

type props = [ `All | `Names of string list | `PropId of Property.t ]

let default_requires mode kf =
  if Cil.is_default_behavior mode.bhv then [] else
    try
      let bhv = List.find Cil.is_default_behavior (Annotations.behaviors kf) in
      CfgAnnot.get_requires kf Kglobal bhv
    with Not_found -> []

(* -------------------------------------------------------------------------- *)
(* --- Property Selection by Mode                                         --- *)
(* -------------------------------------------------------------------------- *)

let is_default_bhv (m: mode) = Cil.is_default_behavior m.bhv

let is_selected_bhv (m: mode) (bhv: funbehavior) =
  m.bhv.b_name = bhv.b_name

let is_selected_for (m: mode) ~goal (fors: string list) =
  (fors=[] && (not goal || is_default_bhv m)) ||
  List.mem m.bhv.b_name fors

let is_selected_ca (m: mode) ~goal (ca: code_annotation) =
  match ca.annot_content with
  | AAssigns(forb,_)
  | AAllocation(forb,_)
  | AAssert(forb,_)
  | AInvariant(forb,_,_)
    -> is_selected_for m ~goal forb
  | AVariant _ -> is_default_bhv m
  | AExtended _ | AStmtSpec _ | APragma _ ->
      assert false (* n/a *)

let is_active_mode ~mode ~goal (p: Property.t) =
  let open Property in
  match p with
  | IPCodeAnnot { ica_ca } -> is_selected_ca mode ~goal ica_ca
  | IPPredicate { ip_kind } ->
      begin match ip_kind with
        | PKRequires bhv | PKAssumes bhv ->
            Cil.is_default_behavior bhv || is_selected_bhv mode bhv
        | PKEnsures(bhv,_) -> is_selected_bhv mode bhv
        | PKTerminates -> is_default_bhv mode
      end
  | IPAllocation { ial_bhv = bhv } | IPAssigns { ias_bhv = bhv } ->
      begin match bhv with
        | Id_loop ca -> is_selected_ca mode ~goal ca
        | Id_contract(_,bhv) -> is_selected_bhv mode bhv
      end
  | IPDecrease { id_ca = None } -> is_default_bhv mode
  | IPDecrease { id_ca = Some ca } -> is_selected_ca mode ~goal ca
  | IPComplete _ | IPDisjoint _ -> is_default_bhv mode
  | IPFrom _ | IPGlobalInvariant _ | IPTypeInvariant _ ->
      (*TODO: is it in pass or not ? *) assert false
  | IPAxiomatic _ | IPAxiom _ | IPLemma _
  | IPOther _ | IPExtended _ | IPBehavior _
  | IPReachable _ | IPPropertyInstance _
    -> assert false (* n/a *)

let is_selected_props (props : props) ?pi pid =
  WpPropId.filter_status pid &&
  match props with
  | `All | `Names [] -> WpPropId.select_default pid
  | `Names ps -> WpPropId.select_by_name ps pid
  | `PropId p ->
      Property.equal p @@ match pi with
      | Some q -> q
      | None -> WpPropId.property_of_id pid

(* -------------------------------------------------------------------------- *)
(* --- WP Calculus Driver from Interpreted Automata                       --- *)
(* -------------------------------------------------------------------------- *)

module Make(W : Mcfg.S) =
struct

  module I = CfgInit.Make(W)

  (* --- Traversal Environment --- *)

  type env = {
    mode: mode;
    props: props;
    body: Cfg.automaton option;
    succ: Cfg.vertex -> Cfg.G.edge list;
    we: W.t_env;
    wp: W.t_prop option Vhash.t; (* None is used for non-dag detection *)
    mutable wk: W.t_prop; (* end point *)
  }

  (* --- Annotation Helpers --- *)

  let fmerge env f = function
    | [] -> W.empty
    | [x] -> f x
    | x::xs ->
        let cup = W.merge env.we in
        List.fold_left (fun p y -> cup (f y) p) (f x) xs

  let is_selected ~goal { mode ; props } (pid,_) =
    let pi = WpPropId.property_of_id pid in
    is_active_mode ~mode ~goal pi &&
    ( not goal || is_selected_props props ~pi pid )

  let is_selected_callpre { props } (pid,_) =
    is_selected_props props pid

  let use_assigns env (a : assigns) w =
    match a with
    | NoAssignsInfo -> assert false
    | AssignsAny ad ->
        WpLog.warning ~current:true ~once:true
          "Missing assigns clause (assigns 'everything' instead)" ;
        W.use_assigns env.we None ad w
    | AssignsLocations(ap,ad) -> W.use_assigns env.we (Some ap) ad w

  let prove_assigns env (a : assigns) w =
    match a with
    | NoAssignsInfo | AssignsAny _ -> w
    | AssignsLocations ai ->
        if is_selected ~goal:true env ai
        then W.add_assigns env.we ai w
        else w

  let use_property env (p : WpPropId.pred_info) w =
    if is_selected ~goal:false env p then W.add_hyp env.we p w else w

  let prove_property env (p : WpPropId.pred_info) w =
    if is_selected ~goal:true env p then W.add_goal env.we p w else w

  (* --- Decomposition of WP Rules --- *)

  exception NonNaturalLoop

  let rec wp (env:env) (a:vertex) : W.t_prop =
    match Vhash.find env.wp a with
    | None -> raise NonNaturalLoop
    | Some pi -> pi
    | exception Not_found ->
        (* cut circularities *)
        Vhash.add env.wp a None ;
        let pi = match a.vertex_start_of with
          | None -> successors env a
          | Some s -> stmt env a s
        in Vhash.replace env.wp a (Some pi) ; pi

  (* Compute a stmt node *)
  and stmt env a (s: stmt) : W.t_prop =
    let kl = Cil.CurrentLoc.get () in
    try
      Cil.CurrentLoc.set (Stmt.loc s) ;
      let ca = CfgAnnot.get_code_assertions env.mode.kf s in
      let pi =
        W.label env.we (Some s) (Clabels.stmt s) @@
        List.fold_right (prove_property env) ca.code_verified @@
        List.fold_right (use_property env) ca.code_admitted @@
        control env a s
      in
      Cil.CurrentLoc.set kl ; pi
    with err ->
      Cil.CurrentLoc.set kl ; raise err

  (* Branching wrt control-flow *)
  and control env a s : W.t_prop =
    match a.vertex_control with
    | If { cond ; vthen ; velse } ->
        W.test env.we s cond (wp env vthen) (wp env velse)
    | Switch { value ; cases ; default } ->
        W.switch env.we s value
          (List.map (fun (e,v) -> [e], wp env v) cases)
          (wp env default)
    | Loop _ -> loop env a s (CfgAnnot.get_loop_contract env.mode.kf s)
    | Edges -> successors env a

  (* Compute loops *)
  and loop env a s (lc : CfgAnnot.loop_contract) : W.t_prop =
    let loop_current = Clabels.loop_current s in
    let established =
      W.label env.we None loop_current @@
      List.fold_right (prove_property env) lc.loop_established W.empty in
    let presersed =
      List.fold_right (use_assigns env) lc.loop_assigns @@
      W.label env.we None loop_current @@
      List.fold_right (use_property env) lc.loop_invariants @@
      let q =
        List.fold_right (prove_property env) lc.loop_preserved @@
        List.fold_right (prove_assigns env) lc.loop_assigns @@
        W.empty in
      ( Vhash.replace env.wp a (Some q) ; successors env a )
    in
    W.merge env.we established presersed

  (* Merge transitions *)
  and successors env (a : vertex) = transitions env (env.succ a)
  and transitions env (es : G.edge list) = fmerge env (transition env) es
  and transition env (_,edge,dst) : W.t_prop =
    let p = wp env dst in
    match edge.edge_transition with
    | Skip -> p
    | Return(r,s) -> W.return env.we s r p
    | Enter { blocals=[] } | Leave { blocals=[] } -> p
    | Enter { blocals=xs } -> W.scope env.we xs SC_Block_in p
    | Leave { blocals=xs } -> W.scope env.we xs SC_Block_out p
    | Instr (i,s) -> instr env s i p
    | Prop _ | Guard _ -> (* soundly ignored *) p

  (* Compute a single instruction *)
  and instr env s instr (w : W.t_prop) : W.t_prop =
    match instr with
    | Skip _ | Code_annot _ -> w
    | Set(lv,e,_) -> W.assign env.we s lv e w
    | Local_init(x,AssignInit i,_) -> W.init env.we x (Some i) w
    | Local_init(x,ConsInit (vf, args, kind), loc) ->
        Cil.treat_constructor_as_func
          begin fun r fct args _loc ->
            match Kf.get_called fct with
            | Some kf -> call env s r kf args w
            | None ->
                WpLog.warning ~once:true "No function for constructor '%s'"
                  vf.vname ;
                let any = WpPropId.mk_stmt_assigns_any_desc s in
                W.use_assigns env.we None any (W.merge env.we w env.wk)
          end x vf args kind loc
    | Call(res,fct,args,_loc) ->
        begin
          match Kf.get_called fct with
          | Some kf -> call env s res kf args w
          | None ->
              match Dyncall.get ~bhv:env.mode.bhv.b_name s with
              | None ->
                  WpLog.warning ~once:true "Missing 'calls' for %s"
                    (if Cil.is_default_behavior env.mode.bhv
                     then "default behavior"
                     else env.mode.bhv.b_name) ;
                  let any = WpPropId.mk_stmt_assigns_any_desc s in
                  W.use_assigns env.we None any (W.merge env.we w env.wk)
              | Some(prop,kfs) ->
                  let id = WpPropId.mk_property prop in
                  W.call_dynamic env.we s id fct @@
                  List.map (fun kf -> kf, call env s res kf args w) kfs
        end
    | Asm _ ->
        W.use_assigns env.we None (WpPropId.mk_asm_assigns_desc s) w

  and call env s r kf es wr : W.t_prop =
    let c = CfgAnnot.get_call_contract kf in
    let w_call = W.call env.we s r kf es
        ~pre:c.call_pre
        ~post:c.call_post
        ~pexit:c.call_exit
        ~assigns:c.call_assigns
        ~p_post:wr ~p_exit:env.wk in
    if is_default_bhv env.mode then
      let pre =
        List.filter_map (fun p ->
            if is_selected_callpre env p then
              Some (CfgAnnot.get_precond_at kf s p)
            else None
          ) c.call_pre
      in W.call_goal_precond env.we s kf es ~pre w_call
    else w_call

  let do_complete_disjoint env w =
    if not (is_default_bhv env.mode) then w
    else
      let kf = env.mode.kf in
      let complete = CfgAnnot.get_complete_behaviors kf in
      let disjoint = CfgAnnot.get_disjoint_behaviors kf in
      List.fold_right (prove_property env) complete @@
      List.fold_right (prove_property env) disjoint w

  let do_global_init env w =
    I.process_global_init env.we env.mode.kf @@
    W.scope env.we [] SC_Global w

  let do_preconditions env ~formals bhvs w =
    let kf = env.mode.kf in
    let init = WpStrategy.is_main_init kf in
    let behaviors =
      if init || WpLog.PrecondWeakening.get () then []
      else CfgAnnot.get_preconditions ~goal:false kf in
    let defaults = default_requires env.mode kf in
    let requires = bhvs.CfgAnnot.bhv_requires in
    let initreqs = if init then requires else [] in
    let assumes = bhvs.CfgAnnot.bhv_assumes in
    (* pre-state *)
    W.label env.we None Clabels.pre @@
    (* frame-in *)
    W.scope env.we formals SC_Frame_in @@
    (* pre-conditions *)
    List.fold_right (use_property env) defaults @@
    List.fold_right (use_property env) assumes @@
    List.fold_right (prove_property env) initreqs @@
    List.fold_right (use_property env) requires @@
    List.fold_right (use_property env) behaviors w

  let do_post env ~formals (b : CfgAnnot.behavior) w =
    W.scope env.we formals SC_Frame_out @@
    W.label env.we None Clabels.post @@
    List.fold_right (prove_property env) b.bhv_ensures @@
    prove_assigns env b.bhv_post_assigns w

  let do_exit env ~formals (b : CfgAnnot.behavior) w =
    W.scope env.we formals SC_Frame_out @@
    W.label env.we None Clabels.at_exit @@
    List.fold_right (prove_property env) b.bhv_exits @@
    prove_assigns env b.bhv_exit_assigns w

  let do_funbehavior env ~formals (b:CfgAnnot.behavior) w =
    match env.body with
    | None -> w
    | Some cfg ->
        let wpost = do_post env ~formals b w in
        let wexit = do_exit env ~formals b w in
        Vhash.add env.wp cfg.return_point (Some wpost) ;
        env.wk <- wexit ;
        wp env cfg.entry_point

  (* Putting everything together *)
  let compute ~mode ~props =
    let kf = mode.kf in
    let infos = mode.infos in
    let body = CfgInfos.body infos in
    let succ = match body with
      | None -> (fun _ -> [])
      | Some cfg -> Cfg.G.succ_e cfg.graph in
    let env = {
      mode ; props ; body ; succ ;
      we = W.new_env kf ;
      wp = Vhash.create 32 ;
      wk = W.empty ;
    } in
    let formals = Kf.get_formals kf in
    let exits = not @@ Kf.Set.is_empty @@ CfgInfos.calls infos in
    let bhv = CfgAnnot.get_behavior kf Kglobal ~exits ~active:[] mode.bhv in
    begin
      W.close env.we @@
      do_global_init env @@
      do_preconditions env ~formals bhv @@
      do_complete_disjoint env @@
      do_funbehavior env ~formals bhv @@
      W.empty
    end

end

(* -------------------------------------------------------------------------- *)
