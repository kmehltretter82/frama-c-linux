(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Why3.Ident
open Why3.Env
open Why3.Ty
open Why3.Term
open Why3.Decl
open Why3.Theory

(** {2 Qed Symbols} *)

(** Abstract Data Types *)
type data

(** Returns an empty list for pure ADT *)
val constructors : data -> constructor list

(** Record Fields *)
type field

(** Returns an empty list for non-record data *)
val fields : data -> field list

(** @raise Not_found for non-record data *)
val field : data -> string -> field

(** Ordering with respect to field declaration order in record *)
val by_field_rank : field -> field -> int

(** Logic Types *)
type tau = (field,data) Logic.datatype

val data : data -> tau list -> tau
(** Converts builtin Qed types from external data symbols *)

(** Logic Functions *)
type lfun

(** Returns a triple [a,r,vs] with [a] the number of polymorphic variables, [r]
    the type of result and [vs] the type of arguments. *)
val signature : lfun -> int * tau * tau list

(** Returns an optional pair [Some(xs,def)] with [xs] the formal parameters
    and [def] the defining term. Returns [None] when the function is abstract. *)
val definition : lfun -> (Why3.Term.vsymbol list * Why3.Term.term) option

(**
   Unifies the polymorphic types of the function with the provided type of
   arguments and of the result, when available. If you provide a result type, it
   {i will} be unified with the expected result type of the logic symbol, so use
   [~result:Prop] for predicates. *)
val apply : lfun -> ?result:tau -> tau list -> tau

(** {2 Symbol Lookup} *)

val find_ts : env -> string -> (theory -> tysymbol -> 'a) -> 'a
val find_ls : env -> string -> (theory -> lsymbol -> 'a) -> 'a
val find_pr : env -> string -> (theory -> prsymbol -> 'a) -> 'a
val find_use : context:theory -> ident -> theory

(** Memoized.
    @raise Invalid_argument if undefined in context *)
val of_ts : theory -> tysymbol -> data

type sigma = tau Why3.Ty.Mtv.t

(** Converts infix, prefix and mixfix names to user names.
    Typically: [of_infix "infix +" = "(+)"].
    Returns identity for usual identifiers *)
val of_infix : string -> string

(** Reverse of [of_infix]. Typically: [to_infix "(+)" = "infix +"]. *)
val to_infix : string -> string

(** Memoized.
    @raise Invalid_argument if undefined in context *)
val of_ty : theory -> ?sigma:sigma -> ty -> tau

(** Memoized. [None] means [Prop].
    @raise Invalid_argument if undefined in context *)
val of_oty : theory -> ?sigma:sigma -> ty option -> tau

(** Memoized.
    @raise Invalid_argument if undefined in context *)
val of_ls : theory -> lsymbol -> lfun

(** Memoized in environment.
    Expect fully qualified identifiers, typically ["int.Int.int"].
    @raise Invalid_argument if not found in environment *)
val find_data : env -> string -> data

(** Memoized in environment.
    Expect fully qualified identifiers, typically ["int.Int.(+)"].
    @raise Invalid_argument if not found in environment *)
val find_lfun : env -> string -> lfun

(** {2 Symbol Factory} *)

type cluster

val cluster : ?path:string list -> ?loc:Why3.Loc.position -> string -> cluster
val add : cluster -> Why3.Decl.decl -> unit
val use : cluster -> Why3.Theory.theory -> unit
val use_data : cluster -> data -> unit
val use_lfun : cluster -> lfun -> unit
val new_data : cluster -> Why3.Ty.tysymbol -> data
val new_lfun : cluster -> Why3.Term.lsymbol -> lfun
val close : cluster -> Why3.Theory.theory

(** {2 Symbol Modules} *)

module type Symbol =
sig

  type t (** Qed symbol *)

  type symbol (** Why3 symbol *)

  val hash : t -> int
  val equal : t -> t -> bool
  val compare : t -> t -> int

  val name : t -> string
  val fullname : t -> string
  val pretty : Format.formatter -> t -> unit

  val symbol : t -> symbol
  val ident : t -> ident
  val theory : t -> theory
end

module Data : Symbol with type t = data and type symbol = tysymbol
module Field : Symbol with type t = field and type symbol = lsymbol
module Fun : Symbol with type t = lfun and type symbol = lsymbol
module Tau :
sig
  type t = tau
  val hash : t -> int
  val equal : t -> t -> bool
  val compare : t -> t -> int
  val pretty : Format.formatter -> t -> unit
end
