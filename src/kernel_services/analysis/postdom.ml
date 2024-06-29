(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2024                                               *)
(*    CEA (Commissariat à l'énergie atomique et aux énergies              *)
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

(* This module performs dataflow analysis using [Interpreted_automata] to
   compute the domination/postdomination dependancies between statements of a
   given function. *)

open Cil_types
open Interpreted_automata

(* Datatype used to create a dot graph using analysis results. *)
module StmtTbl = Cil_datatype.Stmt.Hashtbl

(* State type for our domain. *)
module StmtSet = struct
  include Cil_datatype.Stmt.Hptset
  let pretty fmt set =
    Pretty_utils.pp_iter ~pre:"@[{" ~sep:",@," ~suf:"}@]"
      iter (fun fmt stmt -> Format.pp_print_int fmt stmt.sid)
      fmt set

  (* [find_opt_for_all f set] find the first element [a] of the [set] which
     satisfies [f a b] on all elements [b] of [set] (including himself). *)
  let find_opt_for_all f set =
    let f' a = for_all (fun b -> f a b) set in
    List.find_opt f' (elements set)
end

(* Used to store the result of the analysis. [None] means the statement is
   unreachable while [Some set] means the statement was reached with this set
   of statements. *)
module StmtSetOpt = struct
  include Datatype.Option (StmtSet)

  let remove s setopt =
    Option.map (StmtSet.remove s) setopt

  let mem s setopt =
    Option.fold ~none:false ~some:(StmtSet.mem s) setopt

  let inter s s' =
    match s, s' with
    | None, None -> None
    | Some s, None | None, Some s -> Some s
    | Some s, Some s' -> Some (StmtSet.inter s s')

  let find_opt_for_all f setopt =
    Option.bind setopt (StmtSet.find_opt_for_all f)

  let pretty fmt setopt =
    Pretty_utils.pp_opt ~none:"Top" StmtSet.pretty fmt setopt
end

module DotGraph = Graph.Graphviz.Dot (
  struct
    type t = string * (StmtSetOpt.t StmtTbl.t)
    module V = struct
      type t = stmt
      let pretty fmt v = Cil_printer.pp_stmt fmt v
    end
    module E = struct
      type t = (V.t * V.t)
      let src = fst
      let dst = snd
    end

    let iter_vertex f (_, graph) =
      StmtTbl.iter (fun stmt _ -> f stmt) graph

    let iter_edges_e f (_, graph) =
      let do_edges stmt set_opt =
        let do_edge p = f (p, stmt) in
        Option.iter (fun set -> StmtSet.iter do_edge set) set_opt
      in
      StmtTbl.iter do_edges graph

    let graph_attributes (title, _) = [`Label title]

    let default_vertex_attributes _g = [`Shape `Box; `Style `Filled]

    let vertex_name stmt = string_of_int stmt.sid

    let vertex_attributes stmt =
      let txt = Format.asprintf "%a" V.pretty stmt in
      [`Label txt]

    let default_edge_attributes _g = []

    let edge_attributes _s = []

    let get_subgraph _v = None
  end)

(* Both analysis are using this domain. It simply propagate all encountered
   statements by adding them to the state. The [join] performs an intersection
   which is enough to compute domination/postdomination. *)
module Domain = struct
  type t = StmtSet.t

  let join = StmtSet.inter

  let widen a b =
    if StmtSet.subset a b then
      Fixpoint
    else
      Widening (join a b)

  (* Trivial transfert function : add all visited statements to the current
     state. *)
  let transfer v _ state =
    match v.vertex_start_of with
    | None -> Some state
    | Some stmt -> Some (StmtSet.add stmt state)
end

(* An analysis needs a name and a starting point. *)
module type Analysis = sig
  val name : string
  val get_starting_stmt : kernel_function -> stmt
  include DataflowAnalysis with type state = Domain.t
end

(* Main module, perform the analysis, store its results and provide ways to
   access them. *)
module Compute (Analysis : Analysis) = struct

  module Table =
    Cil_state_builder.Stmt_hashtbl
      (StmtSetOpt)
      (struct
        let name = Analysis.name ^ "_table"
        let dependencies = [Ast.self]
        let size = 503
      end)

  let compute kf =
    let init_stmt = Analysis.get_starting_stmt kf in
    match Table.find_opt init_stmt with
    | Some _ ->
      Kernel.feedback ~level:2 "%s analysis already computed for function %a"
        Analysis.name Kernel_function.pretty kf
    | None ->
      match kf.fundec with
      | Definition (f, _) ->
        Kernel.feedback ~level:2 "computing %s analysis for function %a"
          Analysis.name Kernel_function.pretty kf;
        (* Compute the analysis, initial state is empty. *)
        let result = Analysis.fixpoint kf StmtSet.empty in
        (* Fill table with all statements. *)
        List.iter (fun stmt -> Table.add stmt None) f.sallstmts;
        (* Update the table with analysis results. *)
        Analysis.Result.iter_stmt (fun s set ->
            (* A statement always (post)dominates itself, so we add it here. *)
            Table.replace s (Some (StmtSet.add s set))
          ) result;
        Kernel.feedback ~level:2 "done for function %a"
          Kernel_function.pretty kf
      (* [Analysis.get_starting_stmt] should fatal before this point. *)
      | Declaration _ -> assert false

  let find_kf stmt =
    try Kernel_function.find_englobing_kf stmt
    with Not_found ->
      Kernel.fatal "Statement %d is not part of a function" stmt.sid

  (* Generic function to get the set of (post)dominators of [stmt]. *)
  let get stmt =
    let kf = find_kf stmt in
    match Table.find_opt stmt with
    | None -> compute kf; Table.find stmt
    | Some v -> v

  (* Generic function to get the set of strict (post)dominators of [stmt]. *)
  let get_strict stmt = get stmt |> StmtSetOpt.remove stmt

  (* Generic function to test the (post)domination of 2 statements. *)
  let mem a b = get b |> StmtSetOpt.mem a

  (* Generic function to test the strict (post)domination of 2 statements. *)
  let mem_strict a b = get_strict b |> StmtSetOpt.mem a

  (* The nearest common ancestor (resp. children) is the ancestor which is
     dominated (resp. postdominated) by all common ancestors, ie. the lowest
     (resp. highest) ancestor in the domination tree. *)
  let nearest stmtl =
    let exception Unreachable in
    (* Get the set of strict (post)doms for each statement and intersect them to
       keep the common ones. If one of them is None (unreachable), they do not
       share a common ancestor/children. *)
    let common_set =
      try
        List.fold_left (fun acc s ->
            match get_strict s with
            | None -> raise Unreachable
            | set -> StmtSetOpt.inter acc set
          ) None stmtl
      with Unreachable -> None
    in
    (* Try to find a statement [s] in [common_set] which is (post)dominated by
       all statements of the [common_set]. *)
    StmtSetOpt.find_opt_for_all (Fun.flip mem) common_set

  let pretty fmt () =
    let l = Table.to_seq () |> List.of_seq in
    Pretty_utils.pp_list ~pre:"@[<v>" ~sep:"@;" ~empty:"Empty"
      (fun fmt (k,v) ->
         Format.fprintf fmt "Stmt:%d -> @[%a@]" k.sid StmtSetOpt.pretty v
      ) fmt l

  let get_set graph stmt =
    match StmtTbl.find_opt graph stmt with
    | Some None -> assert false
    | Some (Some l) -> l
    | None ->
      match get_strict stmt with
      | Some set ->
        StmtTbl.add graph stmt (Some set); set
      | None ->
        StmtTbl.add graph stmt None;
        raise Not_found

  (* [s_set] are [s] (post)dominators, including [s]. We don't have to represent
     the relation between [s] and [s], so [get_set] removes it. And because the
     (post)domination relation is transitive, if [p] is in [s_set], we can
     remove [p_set] from [s_set] in order to have a clearer graph.
  *)
  let reduce graph s =
    (* Union of all (post)dominators of [s] (post)dominators [s_set]. *)
    let unions p acc = get_set graph p |> StmtSet.union acc in
    try
      let s_set = get_set graph s in
      let p_sets = StmtSet.fold unions s_set StmtSet.empty in
      let res = StmtSet.diff s_set p_sets in
      StmtTbl.replace graph s (Some res)
    with Not_found -> ()

  let build_dot filename kf =
    match kf.fundec with
    | Definition (fct, _) ->
      let graph = StmtTbl.create (List.length fct.sallstmts) in
      List.iter (reduce graph) fct.sallstmts;
      let name = Kernel_function.get_name kf in
      let title = Format.sprintf "%s for function %s" Analysis.name name in
      let file = open_out filename in
      DotGraph.output_graph file (title, graph);
      close_out file
    | Declaration _ ->
      Kernel.fatal "cannot compute for a function without body %a"
        Kernel_function.pretty kf

  let print_dot basename kf =
    let filename = basename ^ "." ^ Kernel_function.get_name kf ^ ".dot" in
    build_dot filename kf;
    Kernel.result "dot file generated in %s" filename
end

(* ---------------------------------------------------------------------- *)
(* --- Dominators                                                     --- *)
(* ---------------------------------------------------------------------- *)

module Dominators = struct
  module Analysis = struct
    include ForwardAnalysis (Domain)
    let name = "Dominators"
    let get_starting_stmt kf =
      try Kernel_function.find_first_stmt kf
      with Kernel_function.No_Statement ->
        Kernel.fatal "No first statement in function %a"
          Kernel_function.pretty kf
  end
  include Compute (Analysis)
end

let compute_dominators = Dominators.compute

let get_dominators = Dominators.get

let get_strict_dominators = Dominators.get_strict

let dominates = Dominators.mem

let strictly_dominates = Dominators.mem_strict

let get_idom s = Dominators.nearest [s]

let nearest_common_ancestor = Dominators.nearest

let pretty_dominators = Dominators.pretty

let print_dot_dominators = Dominators.print_dot

(* ---------------------------------------------------------------------- *)
(* --- Postdominators                                                 --- *)
(* ---------------------------------------------------------------------- *)

module PostDominators = struct
  module Analysis = struct
    include BackwardAnalysis (Domain)
    let name = "PostDominators"
    let get_starting_stmt kf =
      try Kernel_function.find_return kf
      with Kernel_function.No_Statement ->
        Kernel.fatal "No return statement in function %a"
          Kernel_function.pretty kf
  end
  include Compute (Analysis)
end

let compute_postdominators = PostDominators.compute

let get_postdominators = PostDominators.get

let get_strict_postdominators = PostDominators.get_strict

let postdominates = PostDominators.mem

let strictly_postdominates = PostDominators.mem_strict

let get_ipostdom s = PostDominators.nearest [s]

let nearest_common_children = PostDominators.nearest

let pretty_postdominators = PostDominators.pretty

let print_dot_postdominators = PostDominators.print_dot
