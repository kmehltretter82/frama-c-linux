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

(** Interval inference for terms.

    Compute the smallest interval that contains all the possible values of a
    given integer term. The interval of C variables is directly inferred from
    their C type. The interval of logic variables must be registered from
    outside before computing the interval of a term containing such variables
    (see module {!Interval.Env}).

    It implements Figure 3 of J. Signoles' JFLA'15 paper "Rester statique pour
    devenir plus rapide, plus précis et plus mince".
    Also implements a partial support for real numbers.

    Example: consider a variable [x] of type [int] on a (strange) architecture
    in which values of type [int] belongs to the interval \[-128;127\] and a
    logic variable [y] which was registered in the environment with an interval
    \[-32;31\]. Then here are the intervals computed from the term
    [1+(x+1)/(y-64)]:
    1. x in \[128;127\];
    2. x+1 in \[129;128\];
    3. y in \[-32;31\];
    4. y-64 in \[-96;-33\];
    5. (x+1)/(y-64) in \[-3;3\];
    6. 1+(x+1)/(y-64) in \[-2;4\]

    Note: this is a partial wrapper on top of [Ival.t], to which most
    functions are delegated. *)

open Cil_types
open Analyses_types
open Analyses_datatype

(* ************************************************************************** *)
(** {3 Useful operations on intervals} *)
(* ************************************************************************** *)
type t = ival

val is_included: t -> t -> bool
val join: t -> t -> t
val meet: t -> t -> t

val widen: t -> t
(** @return the smallest interval containing a disjoint union of intervals *)

val is_singleton_int: t -> bool

(** assume [Ival _] as argument *)
val extract_ival: t -> Ival.t

exception Not_representable_ival
(** raised by {!ikind_of_ival].
    @since Frama-C+dev
*)

val ikind_of_ival: Ival.t -> Cil_types.ikind
(** @return the smallest ikind that contains the given interval.
    @raise Not_representable_ival if the given interval does not fit into any C
    integral type. *)

val interv_of_typ: Cil_types.typ -> t
(** @return the smallest interval which contains the given C type.
    @raise Is_a_real if the given type is a float type.
    @raise Not_a_number if the given type does not represent any number. *)

val extended_interv_of_typ: Cil_types.typ -> t
(** @return the interval [n..m+1] when interv_of_typ returns [n..m].
    It is in particular useful for computing bounds of quantified variables.
    @raise Is_a_real if the given type is a float type.
    @raise Not_a_number if the given type does not represent any number. *)

val plus_one : ival -> ival
(** @return the result of adding one to an interval. This is because when we
      have a condition [x<t], we need to generate [t+1] *)

(* ************************************************************************** *)
(** {3 Inference system} *)
(* ************************************************************************** *)
(* The inference phase infers the smallest possible integer interval which the
   values of the term can fit in. *)

val get_from_profile: profile:Profile.t -> term -> t
(** @return the value computed by the interval inference phase
    @raise Is_a_real if the term is either a float or a real.
    @raise Not_a_number if the term does not represent any
    number.*)

val get: logic_env:Logic_env.t -> term -> t
(** @return the value computed by the interval inference phase, same as
      [get_from_profile] but with a full-fledged logic environment instead of a
      function profile *)


(*****************************************************************************)
(** {2 Interval processing} *)
(*****************************************************************************)

val infer_program : file -> unit
(** compute and store the type of all the terms that will be translated
    in a program *)

val preprocess_predicate :
  logic_env:Logic_env.t -> predicate -> unit
(** compute and store the type of all the terms in a code annotation *)

val preprocess_code_annot :
  logic_env:Logic_env.t -> code_annotation -> unit
(** compute and store the type of all the terms in a code annotation *)

val preprocess_term :
  logic_env:Logic_env.t -> term -> unit

val get_ext_profile : Profile.t -> logic_info -> Profile.t

val clear : unit -> unit

(*
Local Variables:
compile-command: "make -C ../../../../.."
End:
*)
