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

module Cfg = Interpreted_automata
module Fset = Kernel_function.Set
module Shash = Cil_datatype.Stmt.Hashtbl

(* -------------------------------------------------------------------------- *)
(* --- Compute Kernel-Function & CFG Infos for WP                         --- *)
(* -------------------------------------------------------------------------- *)

module CheckPath = Graph.Path.Check(Cfg.G)

type t = {
  body : Cfg.automaton option ;
  checkpath : CheckPath.path_checker option ;
  reachability : WpReached.reachability option ;
  mutable annots : bool; (* has goals to prove *)
  mutable doomed : WpPropId.prop_id Bag.t;
  mutable calls : Kernel_function.Set.t;
}

(* -------------------------------------------------------------------------- *)
(* --- Getters                                                            --- *)
(* -------------------------------------------------------------------------- *)

let body infos = infos.body
let calls infos = infos.calls
let annots infos = infos.annots
let doomed infos = infos.doomed

let wpreached s = function
  | None -> false
  | Some reachability -> WpReached.smoking reachability s
let smoking infos s = wpreached s infos.reachability

let unreachable infos v =
  match infos.body, infos.checkpath with
  | Some cfg , Some checkpath ->
      not @@ CheckPath.check_path checkpath cfg.entry_point v
  | _ -> true

(* -------------------------------------------------------------------------- *)
(* --- Selected Properties                                                --- *)
(* -------------------------------------------------------------------------- *)

let selected ~bhv ~prop pid =
  (prop = [] || WpPropId.select_by_name prop pid) &&
  (bhv = [] || WpPropId.select_for_behaviors bhv pid)

let selected_default ~bhv =
  bhv=[] || List.mem Cil.default_behavior_name bhv

let selected_name ~prop name =
  prop=[] || WpPropId.are_selected_names prop [name]

let selected_assigns ~prop = function
  | Cil_types.WritesAny -> false
  | Writes _ when prop = [] -> true
  | Writes l ->
      let collect_names l (t, _) =
        WpPropId.ident_names t.Cil_types.it_content.term_name @ l
      in
      let names = List.fold_left collect_names ["@assigns"] l in
      WpPropId.are_selected_names prop names

let selected_allocates ~prop = function
  | Cil_types.FreeAllocAny -> false
  | _ -> (selected_name ~prop "@allocates" || selected_name ~prop "@frees")

let selected_precond ~prop ip =
  prop = [] ||
  let tk_name = "@requires" in
  let tp_names = WpPropId.user_pred_names ip.Cil_types.ip_content in
  WpPropId.are_selected_names prop (tk_name :: tp_names)

let selected_postcond ~prop (tk,ip) =
  prop = [] ||
  let tk_name = "@" ^ WpPropId.string_of_termination_kind tk in
  let tp_names = WpPropId.user_pred_names ip.Cil_types.ip_content in
  WpPropId.are_selected_names prop (tk_name :: tp_names)

let selected_requires ~prop (b : Cil_types.funbehavior) =
  List.exists (selected_precond ~prop) b.b_requires

let selected_call ~bhv ~prop kf =
  bhv = [] && List.exists (selected_requires ~prop) (Annotations.behaviors kf)

let selected_clause ~prop name getter kf =
  getter kf <> [] && selected_name ~prop name

let selected_disjoint_complete kf ~bhv ~prop =
  selected_default ~bhv &&
  ( selected_clause ~prop "@complete_behaviors" Annotations.complete kf ||
    selected_clause ~prop "@disjoint_behaviors" Annotations.disjoint kf )

let selected_bhv ~smoking ~bhv ~prop (b : Cil_types.funbehavior) =
  (bhv = [] || List.mem b.b_name bhv) &&
  begin
    (selected_assigns ~prop b.b_assigns) ||
    (selected_allocates ~prop b.b_allocation) ||
    (smoking && b.b_requires <> []) ||
    (List.exists (selected_postcond ~prop) b.b_post_cond)
  end

let selected_main_bhv ~bhv ~prop (b : Cil_types.funbehavior) =
  (bhv = [] || List.mem b.b_name bhv) && (selected_requires ~prop b)

(* -------------------------------------------------------------------------- *)
(* --- Calls                                                              --- *)
(* -------------------------------------------------------------------------- *)

let collect_calls ~bhv stmt =
  let open Cil_types in
  match stmt.skind with
  | Instr(Call(_,fct,_,_)) ->
      begin
        match Kernel_function.get_called fct with
        | Some kf -> Fset.singleton kf
        | None ->
            let bhvs = if bhv = [] then [Cil.default_behavior_name] else bhv in
            List.fold_left
              (fun fs bhv -> match Dyncall.get ~bhv stmt with
                 | None -> fs
                 | Some(_,kfs) -> List.fold_right Fset.add kfs fs
              ) Fset.empty bhvs
      end
  | Instr(Local_init(x,ConsInit(vf, args, kind), loc)) ->
      Cil.treat_constructor_as_func
        (fun _r fct _args _loc ->
           match Kernel_function.get_called fct with
           | Some kf -> Fset.singleton kf
           | None -> Fset.empty)
        x vf args kind loc
  | _ -> Fset.empty

(* -------------------------------------------------------------------------- *)
(* --- Memoization Key                                                    --- *)
(* -------------------------------------------------------------------------- *)

module Key =
struct
  type t = {
    kf: Kernel_function.t ;
    smoking: bool ;
    bhv : string list ;
    prop : string list ;
  }

  let compare a b =
    let cmp = Kernel_function.compare a.kf b.kf in
    if cmp <> 0 then cmp else
      let cmp = Stdlib.compare a.smoking b.smoking in
      if cmp <> 0 then cmp else
        let cmp = Stdlib.compare a.bhv b.bhv in
        if cmp <> 0 then cmp else
          Stdlib.compare a.prop b.prop

  let pp_filter kind fmt xs =
    match xs with
    | [] -> ()
    | x::xs ->
        Format.fprintf fmt "~%s:%s" kind x ;
        List.iter (Format.fprintf fmt ",%s") xs

  let pretty fmt k =
    begin
      Kernel_function.pretty fmt k.kf ;
      pp_filter "smoking" fmt (if k.smoking then ["true"] else []) ;
      pp_filter "bhv" fmt k.bhv ;
      pp_filter "prop" fmt k.prop ;
    end

end

(* -------------------------------------------------------------------------- *)
(* --- Main Collection Pass                                               --- *)
(* -------------------------------------------------------------------------- *)

let dead_posts ~bhv ~prop tk (bhvs : CfgAnnot.behavior list) =
  let post ~bhv ~prop tk (b: CfgAnnot.behavior) =
    let assigns, ps =  match tk with
      | Cil_types.Exits -> b.bhv_exit_assigns, b.bhv_exits
      | _ -> b.bhv_post_assigns, b.bhv_ensures in
    let ps = List.filter (selected ~prop ~bhv) @@ List.map fst ps in
    match assigns with
    | WpPropId.AssignsLocations(id, _) -> Bag.list (id :: ps)
    | _ -> Bag.list ps
  in Bag.umap_list (post ~bhv ~prop tk) bhvs

let loop_contract_pids kf stmt =
  match stmt.Cil_types.skind with
  | Loop _ ->
      let invs = CfgAnnot.get_loop_contract kf stmt in
      let add_assigns assigns l =
        match assigns with
        | WpPropId.NoAssignsInfo | AssignsAny _ -> l
        | AssignsLocations (pid, _) -> pid :: l
      in
      List.fold_right (fun (pid,_) l -> pid :: l) invs.loop_established @@
      List.fold_right (fun (pid,_) l -> pid :: l) invs.loop_preserved @@
      List.fold_right add_assigns invs.loop_assigns []
  | _ -> []

let compile Key.{ kf ; smoking ; bhv ; prop } =
  let body, checkpath, reachability =
    if Kernel_function.has_definition kf then
      let cfg = Cfg.get_automaton kf in
      Some cfg,
      Some (CheckPath.create cfg.graph),
      if smoking then Some (WpReached.reachability kf) else None
    else None, None, None
  in
  let infos = {
    body ; checkpath ; reachability ;
    annots = false ;
    doomed = Bag.empty ;
    calls = Fset.empty ;
  } in
  let behaviors = Annotations.behaviors kf in
  (* Inits *)
  if WpStrategy.is_main_init kf then
    infos.annots <- List.exists (selected_main_bhv ~bhv ~prop) behaviors ;
  (* Function Body *)
  Option.iter
    begin fun (cfg : Cfg.automaton) ->
      (* Spec Iteration *)
      if selected_disjoint_complete kf ~bhv ~prop ||
         (List.exists (selected_bhv ~smoking ~bhv ~prop) behaviors)
      then infos.annots <- true ;
      (* Stmt Iteration *)
      Shash.iter
        (fun stmt (src,_) ->
           let fs = collect_calls ~bhv stmt in
           let dead = unreachable infos src in
           let ca = CfgAnnot.get_code_assertions kf stmt in
           let ca_pids = List.map fst ca.code_verified in
           let loop_pids = loop_contract_pids kf stmt in
           if dead then
             begin
               if wpreached stmt reachability then
                 (let p = CfgAnnot.get_unreachable kf stmt in
                  infos.doomed <- Bag.append infos.doomed p) ;
               infos.doomed <- Bag.concat infos.doomed (Bag.list ca_pids) ;
               infos.doomed <- Bag.concat infos.doomed (Bag.list loop_pids) ;
             end
           else
             begin
               if not infos.annots &&
                  ( List.exists (selected ~bhv ~prop) ca_pids ||
                    List.exists (selected ~bhv ~prop) loop_pids ||
                    Fset.exists (selected_call ~bhv ~prop) fs )
               then infos.annots <- true ;
               infos.calls <- Fset.union fs infos.calls ;
             end
        ) cfg.stmt_table ;
      (* Dead Post Conditions *)
      let dead_exit = Fset.is_empty infos.calls in
      let dead_post = unreachable infos cfg.return_point in
      let bhvs =
        if dead_exit || dead_post then
          let exits = not dead_exit in
          List.map (CfgAnnot.get_behavior_goals kf ~exits) behaviors
        else [] in
      if dead_exit then
        infos.doomed <-
          Bag.concat infos.doomed (dead_posts ~bhv ~prop Exits bhvs) ;
      if dead_post then
        infos.doomed <-
          Bag.concat infos.doomed (dead_posts ~bhv ~prop Normal bhvs) ;
    end body ;
  (* Doomed *)
  Bag.iter
    (fun p -> if WpPropId.filter_status p then WpAnnot.set_unreachable p)
    infos.doomed ;
  (* Collected Infos *)
  infos

(* -------------------------------------------------------------------------- *)
(* --- Memoization Data                                                   --- *)
(* -------------------------------------------------------------------------- *)

module Generator = WpContext.StaticGenerator(Key)
    (struct
      type key = Key.t
      type data = t
      let name = "Wp.CfgInfos.Generator"
      let compile = compile
    end)

let get kf ?(smoking=false) ?(bhv=[]) ?(prop=[]) () =
  Generator.get { kf ; smoking ; bhv ; prop }

let clear () = Generator.clear ()

(* -------------------------------------------------------------------------- *)
