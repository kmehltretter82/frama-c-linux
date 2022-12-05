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




(** Module abstract_state

    implements "points-to" persistent graphs and Steensgaard's
    algorithm (union-find)

    In the graph:

    - Edges are unlabelled.

    - Vertices are labelled by lvalues


    An abstract state is given by:

    - a points-to graph

    - an union-find structure that encodes equivalence classes


    TODO/question: can we use the equivalence relation as an equality to build the graph => yes)


*)
open Graph

open Cil_types



type lset = Cil_datatype.Lval.Set.t  (* sets of lvalues *)

(** module for vertices *)
module V = struct

type t = int


let compare = compare 

let hash = Hashtbl.hash     

let equal= (=)

type label = int

let create x = x

let label x = x 
  end



(** module for points-to graphs - persistant graph *)
module G = Persistent.Digraph.ConcreteBidirectional(V)



module MGU = struct
  (** module for the equivalence class, cf Steensgaard's paper *)


  type ecr = Bottom | Lval of lval (** type ECR = equivalence class representant, basically a lval or Bottom *)

  (** IMPERATIVE union find structure, aka "mgu"; every thime a mgu is
      given as an argument of a function, there may be sides effects *)

  type alpha = int
  type term = ecr
    
  type t = {
    vars : (alpha,term) Hashtbl.t ; (* union-find variables *)
    sigma : (term,term) Hashtbl.t ; (* memoized normalization *)
  }


  (** pretty printer *)
  let pp_ecr _ =
  failwith "not implemented"
    
  let pretty _ =
    failwith "not implemented"

  let concretise  _ =
    failwith "not implemented"

end


module AbstractState = struct

  type graph = G.t (* graph is persistant *)

  type lset = Cil_datatype.Lval.Set.t  (* sets of lvalues *)

  module VMap =Map.Make(V)

  type t = graph * lset VMap.t

  type summary  = t * V.t list (* summary for functions : a state and a list of local variables and parameters (we may need 2 lists) *)

  (** pretty printer *)
  let pretty _ =
  failwith "not implemented"

  (** export the graph to a dot file *)
  let print_dot _ =
  failwith "not implemented"

  (* functions needed for Steensgaard's algorithm *)

  (** [init] creates an "empty" abstract state *)
  let init _ =
  failwith "not implemented"

  (** join / fusion of two ecr; returns the mgu and the new graph ;
     first argument is the union-find struture *)
  let join _ =
  failwith "not implemented"

  (** same as before, but don't join if one of the ecr is Bottom *)
  let cjoin _ =
  failwith "not implemented"

  (** [find a e] returns the ecr corresponding to C expression [e] in abstract state [a] *)
  let find  _ =
  failwith "not implemented"

end



(** Main analysis functions *)

(** Hashtable to store the abstract states; index it with kernel_functions too ? *)
let stmt_table =
  Hashtbl.create 13

let function_table =
  Hashtbl.create 13

(** [do_stmt mgu a s] computes the next abstract state and stores it in stmt_table *)
let do_stmt _ =
  failwith "not implemented"


(** [make_summary mgu a f] computes the summary of a function (and the
   next abstract state if needed) and stores the summary in
   function_table *)
let make_summary  _ =
  failwith "not implemented"
