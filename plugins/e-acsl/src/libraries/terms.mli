(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Cil_types

(** Datatype for terms that relies on physical equality.
    Note that of its collections only [Hashtbl] can be used.
    Using [Map] and [Set] raises a fatal error as they require a comparison
    function, which cannot be defined in a sound way for physical equality. *)
module Id : sig
  include Datatype.S_with_hashtbl with type t = term

  val deep_copy : t -> t
  (** @return a copy of the given term with all sub-terms being copied as well.
      If a term already in the AST is added another time somewhere else in the
      AST, it has to be unshared in this way, so as to preserve the invariant:
      two term nodes in the AST may not be physically identical.
  *)

  val deep_copy_predicate : predicate -> predicate
  (** @return a predicate with all sub-terms occurring within being unshared. *)
end

val has_lv_from_vi: term -> bool
(** @return true iff the given term contains a variables that originates from
    a C varinfo, that is a non-purely logic variable. *)

val is_range_free: term -> bool
(** @return true iff the given term does not contain any range. *)

val of_li: logic_info -> term
(** [term_of_li li] assumes that [li.l_body] matches [LBterm t]
    and returns [t]. *)

val strip_shallow_cast : term -> term
(** remove the first [TCast] if any. *)

val extract_integer : term -> Z.t option
(** return the integer value contained in a [TConst] node if any *)

val mk_TAddrOrTStartOf : loc:Fileloc.t -> term_lval -> term
(** make a [TAddrOf] except if the type of left-value is an C array then it uses
    [TStartOf]. *)
