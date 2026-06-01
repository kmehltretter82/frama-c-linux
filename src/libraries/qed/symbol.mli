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

val find_ts : env -> string -> (theory -> tysymbol -> 'a) -> 'a
val find_ls : env -> string -> (theory -> lsymbol -> 'a) -> 'a
val find_pr : env -> string -> (theory -> prsymbol -> 'a) -> 'a
val find_use : context:theory -> ident -> theory

(** Abstract Data Types *)
type data

(** Returns an empty list for pure ADT *)
val constructors : data -> Why3.Decl.constructor list

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
type sigma = tau Why3.Ty.Mtv.t

val data : data -> tau list -> tau
(** Converts builtin Qed types from external data symbols *)

(** Logic Functions *)
type lfun

(** Returns a triple [a,r,vs] with [a] the number of polymorphic variables, [r]
    the type of result and [vs] the type of arguments. *)
val signature : lfun -> int * tau * tau list

(**
   Unifies the polymorphic types of the function with the provided type of
   arguments and of the result, when available. If you provide a result type, it
   {i will} be unified with the expected result type of the logic symbol, so use
   [~result:Prop] for predicates. *)
val apply : lfun -> ?result:tau -> tau list -> tau

(** Generic Why3 symbols *)
module type Symbol =
sig
  type t
  type symbol

  val hash : t -> int
  val equal : t -> t -> bool
  val compare : t -> t -> int

  val name : t -> string
  val fullname : t -> string
  val pretty : Format.formatter -> t -> unit

  val symbol : t -> symbol
  val ident : t -> Why3.Ident.ident
  val theory : t -> Why3.Theory.theory
end

(** Factory *)

(** @raise Invalid_argument if undefined in context *)
val of_ts : context:theory -> tysymbol -> data

(** @raise Invalid_argument if undefined in context *)
val of_ty : ?sigma:sigma -> context:theory -> ty -> tau

(** @raise Invalid_argument if undefined in context *)
val of_ls : context:theory -> lsymbol -> lfun

(** @raise Invalid_argument if not found in environment *)
val find_data : env -> string -> data

(** @raise Invalid_argument if not found in environment *)
val find_lfun : env -> string -> lfun

module Data : Symbol with type t = data and type symbol = Why3.Ty.tysymbol
module Field : Symbol with type t = field and type symbol = Why3.Term.lsymbol
module Fun : Symbol with type t = lfun and type symbol = Why3.Term.lsymbol
module Tau :
sig
  type t = tau
  val equal : t -> t -> bool
  val compare : t -> t -> int
  val pretty : Format.formatter -> t -> unit
end
