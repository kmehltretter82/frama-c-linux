(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C plug-in 'Alias' (alias).             *)
(*                                                                        *)
(*  Copyright (C) 2022-2022                                               *)
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
(*  for more details (enclosed in the file LICENSE)                       *)
(*                                                                        *)
(**************************************************************************)

open Graph

(* open Cil_types *)

open Cil_datatype

module LSet = Lval.Set


(** module for vertices *)
module V = struct

  type t =
    {
      id : Int.t; (* id must be unique in a graph *)
      set : LSet.t
    }

  (* let cmpt_v = ref (-1) *)

  (* let new_id () = incr cmpt_v; !cmpt_v *)

  let compare x y = Int.compare x.id y.id

  let hash x = Hashtbl.hash x.id (* toto utiliser fonction hash frama-c *)

  let equal x y = (compare x y = 0)

  (* let create s = { id = new_id () ; set = s}
   * 
   * let label x = x.set *)

end


module G = Persistent.Digraph.Concrete(V)

type t = G.t


let pretty fmt (x:t) =
  Format.fprintf fmt "@[<hov 2>List of vertices: @.";
  G.iter_vertex (fun v -> Format.fprintf fmt "(id=%d LSet= %a)@." v.id LSet.pretty v.set) x;
  Format.fprintf fmt "@]@.@[<hov 2>List of edges: @.";
  G.iter_edges (fun v1 v2 -> Format.fprintf fmt "(%d -> %d)@." v1.id v2.id) x;
  Format.fprintf fmt "@]@."

let lset_to_string s =
  let buffer = Buffer.create 16 in
  let fmt = Format.formatter_of_buffer buffer in  
  Format.fprintf fmt "%a" LSet.pretty s ;
  Buffer.contents buffer

module Dot = Graphviz.Dot(struct
   include G
   let edge_attributes _ = []
   let default_edge_attributes _ = []
   let get_subgraph _ = None
   let vertex_attributes _ = [`Shape `Box]
   let vertex_name (v:V.t) = lset_to_string v.set
   let default_vertex_attributes _ = []
  let graph_attributes _ = []
end)

let print_dot filename (graph:t) =
  let file = open_out filename in
  Dot.output_graph file graph;
  close_out file



(** a type for summaries of functions *)
type summary = t (* final type may be different *)

module type Table = sig
  type key
  type value
  val find: key -> value
  (** @raise Not_found if the key is not in the table. *)
end

module Make_table(H: Hashtbl.S)(V: sig type t end) = struct
  type key = H.key
  type value = V.t
  let tbl = H.create 7
  let find = H.find tbl

end

module Stmt_table = Make_table(Cil_datatype.Stmt.Hashtbl)(G)
module Function_table = Make_table(Kernel_function.Hashtbl)(G)

let do_stmt _ =
  failwith "not implemented"

let make_summary  _ =
  failwith "not implemented"
