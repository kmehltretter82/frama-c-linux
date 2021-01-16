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

let guard = function
  | (_,{ Cfg.edge_transition = Guard(_,Then,_) },v) -> `Then v
  | (_,{ Cfg.edge_transition = Guard(_,Else,_) },v) -> `Else v
  | _ -> `None

type assigns = WpPropId.assigns_full_info

(* -------------------------------------------------------------------------- *)
(* --- WP Calculus Driver from Interpreted Automata                       --- *)
(* -------------------------------------------------------------------------- *)

module Make(M : Mcfg.S) =
struct

  (* --- Traversal Environment --- *)

  type env = {
    kf: kernel_function;
    mutable ki: kinstr; (* Current localisation *)
    cfg: Cfg.automaton;
    we: M.t_env;
    wp: M.t_prop option Vhash.t; (* None is used for non-dag detection *)
  }

  (* --- Annotation Helpers --- *)

  let fmerge env f = function
    | [] -> M.empty
    | [x] -> f x
    | x::xs ->
        let cup = M.merge env.we in
        List.fold_left (fun p y -> cup (f y) p) (f x) xs

  let use_assigns env (a : assigns) (w : M.t_prop) : M.t_prop =
    match a with
    | NoAssignsInfo -> assert false
    | AssignsAny ad -> M.use_assigns env.we None ad w
    | AssignsLocations(ap,ad) -> M.use_assigns env.we (Some ap) ad w

  let check_assigns env (a : assigns) (w : M.t_prop) : M.t_prop =
    match a with
    | NoAssignsInfo | AssignsAny _ -> w
    | AssignsLocations ai -> M.add_assigns env.we ai w

  (* --- Decomposition of WP Rules --- *)

  exception NonNaturalLoop of kernel_function * kinstr

  let succ env a = G.succ_e env.cfg.graph a

  let rec wp (env:env) (a:vertex) : M.t_prop =
    match Vhash.find env.wp a with
    | None -> raise (NonNaturalLoop(env.kf,env.ki))
    | Some pi -> pi
    | exception Not_found ->
        (* cut circularities *)
        Vhash.add env.wp a None ;
        let pi = match a.vertex_start_of with
          | None -> successors env a
          | Some s -> stmt env a s
        in Vhash.replace env.wp a (Some pi) ; pi

  (* Compute a stmt node *)
  and stmt env a (s: stmt) : M.t_prop =
    let ki = env.ki in
    let kl = Cil.CurrentLoc.get () in
    try
      env.ki <- Kstmt s ;
      Cil.CurrentLoc.set (Stmt.loc s) ;
      let ca = WpAnnot.get_code_assertions env.kf s in
      let pi =
        M.label env.we (Some s) (Clabels.stmt s) @@
        List.fold_right (M.add_goal env.we) ca.code_verified @@
        List.fold_right (M.add_hyp env.we) ca.code_admitted @@
        control env a s
      in
      Cil.CurrentLoc.set kl ;
      env.ki <- ki ; pi
    with err ->
      Cil.CurrentLoc.set kl ;
      env.ki <- ki ; raise err

  (* Branching wrt control-flow *)
  and control env a s : M.t_prop =
    match s.skind with
    | Loop(_,_,_,_,_) ->
        loop env a s (WpAnnot.get_loop_contract env.kf s)
    | If(e,_,_,_) ->
        begin
          match succ env a with
          | [p;q] -> conditional env s e p q
          | es -> transitions env es
        end
    (*TODO: switches *)
    | _ ->
        successors env a

  (* Compute conditionals *)
  and conditional env s (e: exp) (p: G.edge) (q: G.edge) : M.t_prop =
    begin match guard p, guard q with
      | `Then vthen , `Else velse
      | `Else velse , `Then vthen ->
          if V.equal velse vthen then
            wp env vthen
          else
            M.test env.we s e (wp env vthen) (wp env velse)
      | _ ->
          M.merge env.we (transition env p) (transition env q)
    end

  (* Compute loops *)
  and loop env a s (lc : WpAnnot.loop_contract) : M.t_prop =
    begin
      let loop_current = Clabels.loop_current s in
      M.label env.we None loop_current @@
      List.fold_right (M.add_goal env.we) lc.loop_established @@
      List.fold_right (use_assigns env) lc.loop_assigns @@
      M.label env.we None loop_current @@
      List.fold_right (M.add_hyp env.we) lc.loop_invariants @@
      let q =
        M.label env.we None (Clabels.loop_current s) @@
        List.fold_right (M.add_goal env.we) lc.loop_preserved @@
        List.fold_right (check_assigns env) lc.loop_assigns @@
        M.empty in
      ( Vhash.replace env.wp a (Some q) ; successors env a )
    end

  (* Merge transitions *)
  and successors env (a : vertex) = transitions env (succ env a)
  and transitions env (es : G.edge list) = fmerge env (transition env) es
  and transition env (_,edge,dst) : M.t_prop =
    let p = wp env dst in
    match edge.edge_transition with
    | Skip -> p
    | Return(r,s) -> M.return env.we s r p
    | Enter { blocals=xs } -> M.scope env.we xs SC_Block_in p
    | Leave { blocals=xs } -> M.scope env.we xs SC_Block_out p
    | Instr (i,s) -> instr env s i p
    | Prop _ | Guard _ -> (* soundly ignored *) p

  (* Compute a single instruction *)
  and instr env s instr (p : M.t_prop) : M.t_prop =
    match instr with
    | Skip _ | Code_annot _ -> p
    | Set(lv,e,_) -> M.assign env.we s lv e p
    | Local_init(x,AssignInit i,_) -> M.init env.we x (Some i) p
    | Local_init(x,ConsInit _,_) ->
        WpLog.warning ~once:true
          "Ignored constructor init for '%a' (sound)."
          Varinfo.pretty x ; p
    | Asm _ ->
        M.use_assigns env.we None (WpPropId.mk_asm_assigns_desc s) p
    | Call _ -> assert false

  let return env (p : M.t_prop) : vertex =
    Vhash.add env.wp env.cfg.return_point (Some p) ;
    env.cfg.entry_point

  (* Putting everything together *)
  let compute kf =
    let env = {
      kf ; ki = Kglobal ;
      cfg = Cfg.get_automaton kf ;
      we = M.new_env kf ;
      wp = Vhash.create 32 ;
    } in
    let xs = Kernel_function.get_formals kf in
    env.we ,
    M.scope env.we [] SC_Global @@
    M.label env.we None Clabels.pre @@
    (*TODO: add function requires *)
    M.scope env.we xs SC_Frame_in @@
    wp env @@
    return env @@
    M.scope env.we xs SC_Frame_out @@
    M.empty

end

(* -------------------------------------------------------------------------- *)
