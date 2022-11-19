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


    TODO/question: can we use the equivalence relation as an equality to build the graph (not sure)


*)

open Cil_types


(** module for vertices *)
module V : sig

  type t = lval       (* lvalues *)                                                         
  val compare : t -> t -> int                                                
  val hash : t -> int                                                    
  val equal : t -> t -> bool                                                                 
 end


(** module for points-to graphs *)
module G :
  sig
    type t
    (* directed, persistant ?  graph *)

    val add_vertex : t -> V.t -> t

    val add_edge : t -> (V.t * V.t) -> t

    val remove_edge : t -> (V.t * V.t) -> t

    val merge_vertex : t -> V.t -> V.t -> t

    (* todo add more *)
  end


module MGU : sig
  (** module for the equivalence class, cf Steensgaard's paper *)


  type ecr (* type ECR = equivalence class representant *)

  
  type t (* union find structure *)


  (* functions needed for Steensgaard's algorithm *)
    
  (*  TODO : do it in a procedural or a functional style ? *)
    
  val init : unit -> t
  
  val join : t -> ecr -> ecr -> t (* join of ecr *)

  val cjoin : t -> ecr -> ecr -> t (*  conditional join *)

  val find : t -> exp -> ecr

end


module AbstractState : sig

  type graph = G.t

  type mgu = MGU.t

  type t = graph * mgu (* we may need additional information *)

  type summary (* summary for functions *)

  (*  TODO : version impérative ? *)
  val find : t -> exp -> V.t list

  val do_stmt : t -> stmt -> t

  val make_summary : t -> fundec -> t * summary
    
end
