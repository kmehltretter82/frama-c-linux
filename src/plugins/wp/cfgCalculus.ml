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

(* -------------------------------------------------------------------------- *)
(* --- WP Calculus Driver from Interpreted Automata                       --- *)
(* -------------------------------------------------------------------------- *)

module Make(M : Mcfg.S) =
struct

  type env = {
    kf: kernel_function;
    mutable ki: kinstr; (* Current localisation *)
    cfg: Cfg.automaton;
    we: M.t_env;
    wp: M.t_prop option Vhash.t; (* None is used for non-dag detection *)
  }

  let fmerge env f = function
    | [] -> M.empty
    | [x] -> f x
    | x::xs ->
        let cup = M.merge env.we in
        List.fold_left (fun p y -> cup (f y) p) (f x) xs

  let succ env a = G.succ_e env.cfg.graph a

  exception NonNaturalLoop of kernel_function * kinstr

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
        in Vhash.add env.wp a (Some pi) ; pi

  (* Compute a stmt node *)
  and stmt env a (s: stmt) : M.t_prop =
    let ki = env.ki in
    let kl = Cil.CurrentLoc.get () in
    try
      env.ki <- Kstmt s ;
      Cil.CurrentLoc.set (Stmt.loc s) ;
      let pi = M.label env.we (Some s) (Clabels.stmt s) (annots env a s) in
      Cil.CurrentLoc.set kl ;
      env.ki <- ki ; pi
    with err ->
      Cil.CurrentLoc.set kl ;
      env.ki <- ki ; raise err

  (* Consider annotations *)
  and annots env a (s: stmt) : M.t_prop =
    (*TODO: apply code annots *) branching env a s

  (* Branching wrt control-flow *)
  and branching env a (s: stmt) : M.t_prop =
    match s.skind with
    | If(e,_,_,_) ->
        begin
          match succ env a with
          | [p;q] -> conditional env s e p q
          | es -> transitions env es
        end
    | _ ->
        (*TODO: apply conditional & switches *)
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
    | Local_init(_,ConsInit _,_) -> (* soundly ignored *) p
    | Call _ -> assert false
    | Asm _ -> assert false

  (* Putting everything together *)
  let compute kf =
    let env = {
      kf ; ki = Kglobal ;
      cfg = Cfg.get_automaton kf ;
      we = M.new_env kf ;
      wp = Vhash.create 32 ;
    } in
    env.we , wp env env.cfg.entry_point

end

(* -------------------------------------------------------------------------- *)
