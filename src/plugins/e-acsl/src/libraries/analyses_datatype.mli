(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2023                                               *)
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

(** Datatypes for analyses types *)

open Cil_types
open Analyses_types

module Annotation_kind: Datatype.S with type t = annotation_kind

module Pred_or_term: Datatype.S_with_collections with type t = pred_or_term

module At_data: sig
  include Datatype.S_with_collections with type t = at_data

  val create:
    ?error:exn ->
    kernel_function ->
    kinstr ->
    lscope ->
    pred_or_term ->
    logic_label ->
    at_data
    (** [create ?error kf kinstr lscope pot label] creates an [at_data] from the
        given arguments. *)
end

module Ival_datatype: Datatype.S_with_collections with type t = ival

(** profile that maps logic variables that are function parameters to their
    interval depending on the arguments at the callsite of the function *)
module Profile: sig
  include
    Datatype.S_with_collections
    with type t = ival Cil_datatype.Logic_var.Map.t

  val make: logic_var list -> ival list -> t
  val is_empty: t -> bool
  val empty: t
  val is_included: t -> t -> bool

end

(** term with a profile: a term inside a logic function or predicate may
    contain free variables. The profile indicates the interval for those
    free variables. *)
module Id_term_in_profile: Datatype.S_with_collections
  with type t = term * Profile.t

(** profile of logic function or predicate: a logic info representing a logic
    function or a predicate together with a profile for its arguments. *)
module LFProf: Datatype.S_with_collections
  with type t = logic_info * Profile.t

(** logic environment: interval of all bound variables. It consists in two
    components
    - a profile for variables bound through function arguments
    - an association list for variables bound by a let or a quantification *)
module Logic_env : sig
  type t

  (** forward reference to meet of intervals *)
  val ival_meet_ref : (ival -> ival -> ival) ref

  (** add a new binding for a let or a quantification binder only *)
  val add : t -> logic_var -> ival -> t

  (** the empty environment *)
  val empty : t

  (** create a new environment from a profile, for function calls *)
  val make : Profile.t -> t

  (** find a logic variable in the environment *)
  val find : t -> logic_var -> ival

  (** get the profile of the logic environment, i.e. bindings through function
      arguments *)
  val get_profile : t -> Profile.t

  (** refine the interval of a logic variable: replace an interval with a more
      precise one *)
  val refine : t -> logic_var -> ival -> t
end


(** Imperative environment to perform the fixpoint algorithm for recursive
    functions *)
module LF_env : sig
  (** find the currently inferred interval for a call to a logic function *)
  val find : logic_info -> Profile.t -> ival

  val find_opt : logic_info -> Profile.t -> ival option

  (** clear the table of intervals for logic function (to do between typing )
      each logic function calls *)
  val clear : unit -> unit

  (** add an interval as the current one for a logic function call *)
  val add : logic_info -> Profile.t -> ival -> unit

  (** add 0..1 as the current interval for a predicate call *)
  val add_pred : logic_info -> Profile.t -> unit

  (** determine whether a logic function or predicate is recursive *)
  val is_rec : logic_info -> bool

  (** replace the current interval for a logic function call *)
  val replace : logic_info -> Profile.t -> ival -> unit
end

module Number_ty:  Datatype.S_with_collections
  with type t = number_ty
