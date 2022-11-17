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

    implements "points-to" persistent graphs ans Steensgaard's
   algorithm

    In the graph:

    - Edges are unlabelled.

    - Vertices are labelled by equivalence classes representative
   (ECR)

    ECR are abstract states for Lval sets (pointers that may be
   aliased)


 *)

module CType : sig
  (** placeholder for cil types *)
  type expr (**  expressions *)

  type instr (** instructions *)

  type varinfo (** variable *)
  
  type kf (** functions *)  
end



module ECR : sig
  (** module for the equivalence class, cf Steensgaard's paper *)
  

  (*  following Steensgaard's notations *)
  type alpha = Tau of tau  | Lambda of lambda

  and tau = Bottom_T | Ref of alpha (* points-to type *)

  and lambda = Bottom_L | Lam of alpha list * alpha list

  

  type t (* type ECR = equivalence class representant *)


  (* functions needed for Steensgaard's algorithm *)
    
  (*  TODO : do it in a procedural or a functional style ? *)
    
  val get_type: t -> tau

  val join : t -> t -> unit (* join of ecr *)

  val cjoin : t -> t -> unit (*  conditional join *)

  val ecr : CType.expr -> t

  val set_type : tau -> tau -> unit

  val unify_T : tau -> tau -> unit
    
  val unify_L : lambda -> lambda -> unit

  val pending : tau -> tau list
  
  val make_ecr : int -> tau array (* makes an array of [n] Bottom_T *)
end



(** module for vertices *)
module V : sig

  type t   (*  will have a field for ECR.t set *)                                                                 
  val compare : t -> t -> int                                                
  val hash : t -> int                                                    
  val equal : t -> t -> bool                                                                 
 end


(** module for points-to graphs *)
module G :
  sig
    type t
    (* directed, persistant graph *)

    val add_vertex : t -> V.t -> t

    val add_edge : t -> (V.t * V.t) -> t

    val remove_edge : t -> (V.t * V.t) -> t

    val merge_vertex : t -> V.t -> V.t -> t

    (* todo add more *)
  end



(**  interface for module Alias *)
  

(** type for abstract states aka points-to graphs  *)
type t = G.t


(** type for summary of function, to be determined *)
type summary 

(** initialisation *)
  val compute : unit -> unit

(** evaluation of an expression *)
val eval_expr : t -> CType.expr -> ECR.t

(** abstract semantic of an instruction *)
val do_instr : t -> CType.instr -> t

(** creation of the summary of a function; first argument is the context of the declaration *)
val make_summary : t -> CType.kf -> (t * summary)

val fold_stmt : CType.kf -> CType.varinfo -> ECR.t -> 'a -> 'a
