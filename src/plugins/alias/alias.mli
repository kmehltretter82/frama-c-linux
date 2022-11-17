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




(** External API of the plugin Alias

  
 *)

module CTypes : sig
  (** placeholder for cil types *)
  type expr (**  expressions *)

  type lval (** L-Values *)
  type varinfo (** variables *)

  module LSet : sig type t end (** sets of L-Values *)

  type stmt (** statements *)
  
  type kf (** functions *)
  
end


(** Performes the may-alias analysis. Do it once before using other functions *)
val compute : unit -> unit

(** Minimal API, as presented during kickoff meeting *)
(* we changed:  type varinfo -> type lval *)

val get_class_before_statement : CTypes.stmt ->  CTypes.lval -> CTypes.LSet.t
val get_class_after_statement : CTypes.stmt ->  CTypes.lval -> CTypes.LSet.t

val get_class_fundec: CTypes.kf ->CTypes.lval -> CTypes.LSet.t
val get_class_fundec_stmts: CTypes.kf ->CTypes.lval -> CTypes.LSet.t list



(** other useful functions *)

module AbstractState : sig
  (** placeholder for the abstract state *)
  type t (* abstract state of the program, will be a points-to graph with additional information *)

  type summary (* summary of a function *)

end



(** evaluation of an expression *)
val eval_expr : t -> CTypes.expr -> ECR.t

(** abstract semantic of an instruction *)
val do_instr : t -> CTypes.instr -> t

(** creation of the summary of a function; first argument is the context of the declaration *)
val make_summary : t -> CTypes.kf -> (t * summary)

val fold_stmt : CTypes.kf -> CTypes.varinfo -> ECR.t -> 'a -> 'a
