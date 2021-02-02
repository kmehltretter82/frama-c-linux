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

  module Reachable_call : sig
    val has_reachable_call: Cfg.automaton -> vertex -> bool
  end
  =
  struct
    exception Found_call

    type reachability_env = {
      table: unit Vhash.t ;
      cfg: Cfg.automaton ;
    }

    let rec reachable_call_by_cfg env a =
      try Vhash.find env.table a
      with Not_found ->
        Vhash.add env.table a () ;
        List.iter (transition env) (G.succ_e env.cfg.graph a)

    and transition env (_,edge,dst) =
      reachable_call_by_cfg env dst ;
      match edge.edge_transition with
      | Instr ((Local_init(_,ConsInit _, _)| Call _), _) -> raise Found_call
      | _ -> ()

    let has_reachable_call cfg v =
      let env = { table = Vhash.create 32 ; cfg } in
      try reachable_call_by_cfg env v ; false
      with Found_call -> true

  end

  (* --- Traversal Environment --- *)

  type env = {
    mode: mode;
    props: props;
    cfg: Cfg.automaton;
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

  let succ env a = G.succ_e env.cfg.graph a

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
  and successors env (a : vertex) = transitions env (succ env a)
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
            match Kernel_function.get_called fct with
            | Some kf -> call env s r kf args w
            | None ->
                WpLog.warning ~once:true "No function for constructor '%s'"
                  vf.vname ;
                let any = WpPropId.mk_stmt_assigns_any_desc s in
                W.use_assigns env.we None any (W.merge env.we w env.wk)
          end x vf args kind loc
    | Call(res,fct,args,_loc) ->
        begin
          match Kernel_function.get_called fct with
          | Some kf -> call env s res kf args w
          | None ->
              match Dyncall.get ~bhv:env.mode.bhv.b_name s with
              | None ->
                  WpLog.warning ~once:true "Missing dynamic-call infos." ;
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

  let behaviors kf =
    if WpStrategy.is_main_init kf || WpLog.PrecondWeakening.get () then []
    else CfgAnnot.get_preconditions kf

  let complete mode kf =
    if not (is_default_bhv mode) then []
    else CfgAnnot.get_complete_behaviors kf

  let disjoint mode kf =
    if not (is_default_bhv mode) then []
    else CfgAnnot.get_disjoint_behaviors kf

  let do_preconditions env ~main ~behaviors ~requires ~def_requires ~assumes w =
    let prove_if_main ps w =
      if main then List.fold_right (prove_property env) ps w else w
    in
    List.fold_right (use_property env) def_requires @@
    List.fold_right (use_property env) assumes @@
    prove_if_main requires @@
    List.fold_right (use_property env) requires @@
    List.fold_right (use_property env) behaviors w

  let do_complete_disjoint env ~complete ~disjoint w =
    List.fold_right (prove_property env) complete @@
    List.fold_right (prove_property env) disjoint w

  let do_function_body env w =
    Vhash.add env.wp env.cfg.return_point (Some w) ;
    wp env env.cfg.entry_point

  let do_post_exit env has_exit xs ~post ~post_assigns ~exit ~exit_assigns w =
    let w_exit =
      W.scope env.we xs SC_Frame_out @@
      W.label env.we None Clabels.at_exit @@
      List.fold_right (prove_property env) exit @@
      if has_exit then prove_assigns env exit_assigns w else w
    in
    let w_post =
      W.scope env.we xs SC_Frame_out @@
      W.label env.we None Clabels.post @@
      List.fold_right (prove_property env) post @@
      prove_assigns env post_assigns w
    in
    env.wk <- w_exit ;
    w_post

  (* Putting everything together *)
  let compute ~mode ~props =
    let kf = mode.kf in
    let cfg = Cfg.get_automaton kf in
    let has_exit = Reachable_call.has_reachable_call cfg (cfg.entry_point) in
    let env = {
      mode ; props ;
      cfg ;
      we = W.new_env kf ;
      wp = Vhash.create 32 ;
      wk = W.empty ;
    } in
    let xs = Kernel_function.get_formals kf in
    let bhvs = CfgAnnot.get_behavior kf Kglobal has_exit ~active:[] mode.bhv in

    let def_requires = default_requires mode kf in
    let requires = bhvs.bhv_requires in
    let assumes = bhvs.bhv_assumes in
    let post = bhvs.bhv_ensures in
    let post_assigns = bhvs.bhv_post_assigns in
    let exit = bhvs.bhv_exits in
    let exit_assigns = bhvs.bhv_exit_assigns in
    let main = WpStrategy.is_main_init kf in
    let behaviors = behaviors kf in
    let complete = complete mode kf in
    let disjoint = disjoint mode kf in

    env.we ,
    (* global init *)
    W.close env.we @@
    I.process_global_init env.we kf @@
    W.scope env.we [] SC_Global @@

    (* pre-state *)
    W.label env.we None Clabels.pre @@
    (* frame-in *)
    W.scope env.we xs SC_Frame_in @@

    do_preconditions env ~main ~behaviors ~requires ~def_requires ~assumes @@
    do_complete_disjoint env ~complete ~disjoint @@
    do_function_body env @@

    (* NOTE: do_post_exit performs frame-out on both post and exit *)
    (* Post-conds*)
    do_post_exit env has_exit xs ~post ~post_assigns ~exit ~exit_assigns @@
    (* wp-end *)
    W.empty

end

(* -------------------------------------------------------------------------- *)
