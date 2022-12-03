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


(** module for vertices *)
module V : Sig.VERTEX



(** module for points-to graphs - persistant graph *)
module G : Sig.P



module MGU : sig
  (** module for the equivalence class, cf Steensgaard's paper *)


  type ecr = Bottom | Lval of lval (** type ECR = equivalence class representant, basically a lval or Bottom *)

  (** union find structure, aka "mgu" *)
  type t

  (** pretty printer *)
  val pp_ecr : Format.formatter -> ecr -> unit
    
  val pretty : Format.formatter -> t -> unit

end


module AbstractState : sig

  type graph = G.t

  type mgu = MGU.t

  type t = graph * mgu (* we may need additional information *)

  type summary  = t * V.t list (* summary for functions : a state and a list of local variables and parameters (we may need 2 lists) *)

  (** pretty printer *)
  val pretty : Format.formatter -> t -> unit

  (** export the graph to a dot file *)
  val print_dot : string -> t -> unit

  (* functions needed for Steensgaard's algorithm *)

  (** [init] creates an "empty" abstract state *)
  val init : unit -> t

  (** join  / fusion of two ecr; returns the mgu and the new graph *)
  val join : t -> MGU.ecr -> MGU.ecr -> t

  (** same as before, but don't join if one of the ecr is Bottom *)
  val cjoin : t -> MGU.ecr -> MGU.ecr -> t 

  (** [find a e] returns the ecr corresponding to C expression [e] in abstract state [a] *)
  val find : t -> exp -> MGU.ecr

end



  (* val do_stmt : t -> stmt -> t
   * 
   * val make_summary : t -> fundec -> t * summary *)
