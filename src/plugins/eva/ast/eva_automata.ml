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

open Cil_types
open Eva_ast

(* --- Vertices and Edges types --- *)

type vertex = {
  vertex_key : int;
  vertex_start_of : Cil_types.stmt option;
  mutable vertex_wto_index : vertex list
}

type guard_kind = Interpreted_automata.guard_kind = Then | Else

type transition =
  | Skip
  | Enter of block
  | Leave of block
  | Return of exp option * stmt
  | Guard of exp * guard_kind * stmt
  | Assign of lval * exp * stmt
  | Call of lval option * exp * exp list * stmt
  | Init of varinfo * init * stmt
  | Asm of attributes * string list * extended_asm option * stmt

type edge = {
  edge_key : int;
  edge_kinstr : kinstr;
  edge_transition : transition;
  edge_loc : location;
}

let dummy_vertex = {
  vertex_key = -1;
  vertex_start_of = None;
  vertex_wto_index = [];
}

let dummy_edge = {
  edge_key = -1;
  edge_kinstr = Kglobal;
  edge_transition = Skip;
  edge_loc = Cil_datatype.Location.unknown;
}

module Vertex = Datatype.Make_with_collections (struct
    include Datatype.Serializable_undefined
    type t = vertex
    let reprs = [dummy_vertex]
    let name = "Eva_automata.Vertex"
    let compare v1 v2 = v1.vertex_key - v2.vertex_key
    let hash v = v.vertex_key
    let equal v1 v2 = v1.vertex_key = v2.vertex_key
    let pretty fmt v = Format.pp_print_int fmt v.vertex_key
  end)

module Transition = Datatype.Make (struct
    include Datatype.Serializable_undefined
    type t = transition
    let name = "Eva_automata.Transition"
    let reprs = [Skip]
    let pretty fmt =
      let open Format in
      let print_var_list fmt l =
        Pretty_utils.pp_list ~sep:", " Printer.pp_varinfo fmt l
      in
      function
      | Skip -> ()
      | Return (None,_) -> fprintf fmt "return"
      | Return (Some exp,_) -> fprintf fmt "return %a" Eva_ast.pp_exp exp
      | Guard (exp,Then,_) -> Eva_ast.pp_exp fmt exp
      | Guard (exp,Else,_) -> fprintf fmt "!(%a)" Eva_ast.pp_exp exp
      | Assign (_,_,stmt)
      | Call (_,_,_,stmt)
      | Init (_,_,stmt)
      | Asm (_,_,_,stmt) -> Printer.pp_stmt fmt stmt
      | Enter (b) -> fprintf fmt "Enter %a" print_var_list b.blocals
      | Leave (b)  -> fprintf fmt "Exit %a" print_var_list b.blocals
  end)

module Edge =
struct
  include Datatype.Make_with_collections
      (struct
        include Datatype.Serializable_undefined
        type t = edge
        let reprs = [dummy_edge]
        let name = "Eva_automata.Edge"
        let compare e1 e2 = e1.edge_key - e2.edge_key
        let hash e = e.edge_key
        let equal e1 e2 = e1.edge_key = e2.edge_key
        let pretty fmt e = Transition.pretty fmt e.edge_transition
      end)
  let default = dummy_edge
end


(* --- Automata types --- *)

module G = Graph.Imperative.Digraph.ConcreteBidirectionalLabeled
    (Vertex)
    (Edge)

type graph = G.t

type wto = vertex Wto.partition

module StmtTable = Cil_datatype.Stmt.Hashtbl

type automaton = {
  graph : graph;
  wto : wto;
  entry_point : vertex;
  return_point : vertex;
  stmt_table : (vertex * vertex) StmtTable.t;
}

module Automaton = Datatype.Make
    (struct
      include Datatype.Serializable_undefined
      type t = automaton
      let reprs = [{
          graph=G.create ();
          wto=[];
          entry_point=dummy_vertex;
          return_point=dummy_vertex;
          stmt_table=StmtTable.create 0;
        }]
      let name = "Eva_automata.Automaton"
      let pretty : t Pretty_utils.formatter = fun fmt g ->
        Pretty_utils.pp_iter G.iter_vertex ~pre:"@[" ~suf:"@]" ~sep:";@ "
          (fun fmt v ->
             Format.fprintf fmt "@[<2>@[%a ->@]@ %a@]"
               Vertex.pretty v
               (Pretty_utils.pp_iter (fun f -> G.iter_succ f g.graph) ~sep:",@ " Vertex.pretty)
               v
          )
          fmt g.graph
    end)


(* Wto *)

module Scheduler = Wto.Make (Vertex)

let build_wto graph entry_point =
  let init = entry_point
  and succs = fun v -> G.succ graph v
  and pref v1 v2 =
    match v1.vertex_start_of, v2.vertex_start_of with
    | None, None -> 0
    | None, _ -> -1
    | _ , None -> 1
    | Some _, Some _ -> 0
  in
  Scheduler.partition ~pref ~init ~succs


(* Automata translation *)


let translate_instr stmt instr =
  let translate_call dest callee args _loc =
    let dest' = Option.map translate_lval dest in
    let callee' = translate_exp callee in
    let args' = List.map translate_exp args in
    Call (dest', callee', args', stmt)
  in
  match instr with
  | Cil_types.Set (lval, exp, _loc) ->
    let lval' = translate_lval lval in
    let exp' = translate_exp exp in
    Assign (lval', exp', stmt)
  | Call (dest, callee, args, loc) ->
    translate_call dest callee args loc
  | Local_init (dest, Cil_types.ConsInit (callee, args, k), loc) ->
    Cil.treat_constructor_as_func translate_call dest callee args k loc
  | Local_init (vi, Cil_types.AssignInit init, _loc) ->
    let init' = translate_init init in
    Init (vi, init', stmt)
  | Asm (attributes, string_list, ext_asm_opt, _loc) ->
    Asm (attributes, string_list, ext_asm_opt, stmt)
  | Skip (_loc) | Code_annot (_, _loc) ->
    Skip

let translate_transition transition =
  match transition with
  | Interpreted_automata.Skip -> Skip
  | Return (exp_opt, stmt) ->
    Return (Option.map translate_exp exp_opt, stmt)
  | Guard (exp, guard_kind, stmt) ->
    Guard (translate_exp exp, guard_kind, stmt)
  | Prop _ ->
    Skip
  | Instr (inst, stmt) ->
    translate_instr stmt inst
  | Enter block ->
    Enter block
  | Leave block ->
    Leave block

(* Fill the wto index of the vertices *)
let build_wto_index wto =
  let rec iter_wto index w =
    List.iter (iter_element index) w
  and iter_element index = function
    | Wto.Node v ->
      v.vertex_wto_index <- index
    | Wto.Component (h, w) ->
      let new_index = h :: index in
      iter_wto new_index (Wto.Node h :: w)
  in
  iter_wto [] wto

let generate_literal_strings_bases kf =
  (* Bases id for literal strings are generated the first time a base for the
     string is required. The ordering of bases is built on this id, so the
     order of generation changes the order of pretty printing. This function
     visits the strings of a function in a standard order defined by frama-c
     visitor to ensure the stability of pretty printing. *)
  let visitor = object
    inherit Visitor.frama_c_inplace
    method !vexpr exp =
      match exp.enode with
      | Const (Cil_types.CStr _ | Cil_types.CWStr _) ->
        ignore (Base.of_string_exp exp);
        Cil.SkipChildren
      | _ ->
        Cil.DoChildren
  end
  in
  ignore (Visitor.visitFramacKf visitor kf)

let translate_automaton kf =
  generate_literal_strings_bases kf;
  let module Src = Interpreted_automata in
  let module VertexTable = Src.Vertex.Hashtbl in
  let src = Interpreted_automata.get_automaton kf in
  let size = Src.(G.nb_vertex src.graph) in
  let graph = G.create ~size () in
  let table = VertexTable.create size in
  let translate_vertex (v : Src.vertex) =
    let v' = {
      vertex_key = v.vertex_key;
      vertex_start_of = v.vertex_start_of;
      vertex_wto_index = [];
    }
    in
    G.add_vertex graph v';
    VertexTable.add table v v'
  and translate_edge (v, e, w) =
    let v' = VertexTable.find table v
    and w' = VertexTable.find table w
    and e' = {
      edge_key = e.Src.edge_key;
      edge_kinstr = e.Src.edge_kinstr;
      edge_transition = translate_transition e.Src.edge_transition;
      edge_loc = e.Src.edge_loc;
    }
    in
    G.add_edge_e graph (v',e',w')
  and translate_stmt_table t =
    let module T = Cil_datatype.Stmt.Hashtbl in
    let t' = T.create (T.length t) in
    let translate_pair (v1, v2) =
      VertexTable.find table v1, VertexTable.find table v2
    in
    T.iter (fun stmt (v1, v2) -> T.add t' stmt (translate_pair (v1, v2))) t;
    t'
  in
  Src.G.iter_vertex translate_vertex src.graph;
  Src.G.iter_edges_e translate_edge src.graph;
  let entry_point = VertexTable.find table src.entry_point
  and return_point = VertexTable.find table src.return_point
  and stmt_table = translate_stmt_table src.stmt_table in
  let wto = build_wto graph entry_point in
  build_wto_index wto;
  { graph; wto; entry_point; return_point; stmt_table }


(* Automata memoization *)

module State = Kernel_function.Make_Table (Automaton)
    (struct
      let size = 97
      let name = "Eva_automata.State"
      let dependencies = [Ast.self]
    end)

let get_automaton = State.memo translate_automaton


(* Algorithms *)

let exit_strategy =
  let module Algorithms = Interpreted_automata.Algorithms (G) in
  Algorithms.exit_strategy

let output_to_dot =
  let module Vertex = struct
    include Vertex
    let start_of v = v.vertex_start_of end
  in
  let module Dot = Interpreted_automata.Dot (Vertex) (Edge) (G) in
  fun out automaton ->
    Dot.output_to_dot out ~labeling:`Both ~wto:automaton.wto automaton.graph

let wto_index_diff v1 v2 =
  let index1 = v1.vertex_wto_index and index2 = v2.vertex_wto_index in
  let rec remove_common_prefix l1 l2 =
    match l1, l2 with
    | x :: l1, y :: l2 when Vertex.equal x y ->
      remove_common_prefix l1 l2
    | l1, l2 -> l1, l2
  in
  let l1 = List.rev index1
  and l2 = List.rev index2
  in
  let left, entered = remove_common_prefix l1 l2 in
  List.rev left, entered

let is_wto_head v =
  match v.vertex_wto_index with
  | v' :: _ -> Vertex.equal v v'
  | [] -> false

let is_back_edge (v1,v2) =
  List.exists (Vertex.equal v2) (v1.vertex_wto_index)
