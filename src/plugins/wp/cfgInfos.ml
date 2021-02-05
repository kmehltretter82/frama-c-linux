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
module Vhash = Cfg.Vertex.Hashtbl
module Shash = Cil_datatype.Stmt.Hashtbl

(* -------------------------------------------------------------------------- *)
(* --- Compute Kernel-Function & CFG Infos for WP                         --- *)
(* -------------------------------------------------------------------------- *)

type t = {
  cfg : Cfg.automaton;
  mutable annots : bool; (* has goals to prove *)
  mutable doomed : WpPropId.prop_id Bag.t;
  mutable calls : Kernel_function.Set.t;
  unreachable : bool Vhash.t ;
}

(* -------------------------------------------------------------------------- *)
(* --- Getters                                                            --- *)
(* -------------------------------------------------------------------------- *)

let cfg infos = infos.cfg
let calls infos = infos.calls
let annots infos = infos.annots
let doomed infos = infos.doomed

(* -------------------------------------------------------------------------- *)
(* --- Reachability Analyses                                              --- *)
(* -------------------------------------------------------------------------- *)

let fixpoint h d f =
  let rec phi v =
    try Vhash.find h v
    with Not_found ->
      Vhash.add h v d ;
      let r = f phi v in
      Vhash.replace h v r ; r
  in phi

let unreachable infos =
  let pred = Cfg.G.pred infos.cfg.graph in
  fixpoint infos.unreachable true
    begin fun phi v -> List.for_all phi (pred v) end

(* -------------------------------------------------------------------------- *)
(* --- Selected Properties                                                --- *)
(* -------------------------------------------------------------------------- *)

let selected ~bhv ~prop pid =
  (prop = [] || WpPropId.select_by_name prop pid) &&
  (bhv = [] || WpPropId.select_for_behaviors bhv pid)

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
  type t = { kf: Kernel_function.t ; bhv : string list ; prop : string list }
  let compare a b =
    let cmp = Kernel_function.compare a.kf b.kf in
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
      pp_filter "bhv" fmt k.bhv ;
      pp_filter "prop" fmt k.prop ;
    end
end

(* -------------------------------------------------------------------------- *)
(* --- Main Collection Pass                                               --- *)
(* -------------------------------------------------------------------------- *)

let compile Key.{ kf ; bhv ; prop } =
  let cfg = Cfg.get_automaton kf in
  let infos = {
    cfg ;
    annots = false ;
    doomed = Bag.empty ;
    calls = Fset.empty ;
    unreachable = Vhash.create 32 ;
  } in
  (* Root Reachability *)
  let v0 = cfg.entry_point in
  Vhash.add infos.unreachable v0 false ;
  (* Stmt Iteration *)
  Shash.iter
    (fun stmt (src,_) ->
       let fs = collect_calls ~bhv stmt in
       let dead = unreachable infos src in
       let ca = CfgAnnot.get_code_assertions kf stmt in
       let pids = List.map fst ca.code_verified in
       if dead then
         infos.doomed <- Bag.concat infos.doomed (Bag.list pids)
       else
         begin
           if List.exists (selected ~bhv ~prop) pids
           then infos.annots <- true ;
           infos.calls <- Fset.union fs infos.calls ;
         end
    ) cfg.stmt_table ;
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

let get kf ?(bhv=[]) ?(prop=[]) () = Generator.get { kf ; bhv ; prop }

(* -------------------------------------------------------------------------- *)
