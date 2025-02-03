(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2025                                               *)
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

(** This file contains types related types/functions/values.
    @since Frama-C+dev
    @before Frama-C+dev Most of these functions were in {!Cil}
*)

open Cil_types

(** Returns all the attributes contained in a type. This requires a traversal
    of the type structure, in case of composite, enumeration and named types *)
val type_attrs : typ -> attributes

(** Add some attributes to a type.
    [combine] explains how to combine attributes.
    Default is {!Ast_attributes.adda_ttributes}.
*)
val type_add_attributes :
  ?combine:(attribute list ->
            attributes -> attributes) ->
  attribute list -> typ -> typ

(** Does the type have the given attribute. Does
    not recurse through pointer types, nor inside function prototypes.
*)
val type_has_attribute : string -> typ -> bool

(** Does the type have the given qualifier. Handles the case of arrays, for
    which the qualifiers are actually carried by the type of the elements.
    It is always correct to call this function instead of {!type_has_attribute}.
    For l-values, both functions return the same results, as l-values cannot
    have array type.
*)
val type_has_qualifier : string -> typ -> bool

(** [type_has_attribute_memory_block attr t] is
    [true] iff at least one component of an object of type [t] has attribute
    [attr]. In other words, it searches for [attr] under aggregates, but not
    under pointers.
*)
val type_has_attribute_memory_block : string -> typ -> bool

(** Remove all attributes with the given names from a type. Note that this
    does not remove attributes from typedef and tag definitions, just from
    their uses (unfolding the type definition when needed).
    It only removes attributes of topmost type, i.e. does not
    recurse under pointers, arrays, ...
*)
val type_remove_attributes : string list -> typ -> typ

(** Same as {!type_remove_attributes}, but remove any existing attribute from
    the type.
*)
val type_remove_all_attributes : typ -> typ

(** Same as {!type_remove_attributes}, but recursively removes the given
    attributes from inner types as well. Mainly useful to check whether
    two types are equal modulo some attributes. See also
    {!Cil.typeDeepDropAllAttributes}, which will strip every single attribute
    from a type.
*)
val type_remove_attributes_deep : string list -> typ -> typ

(** Remove all attributes relative to const, volatile and restrict attributes. *)
val type_remove_qualifier_attributes : typ -> typ

(** Remove also qualifiers under Ptr and Arrays. *)
val type_remove_qualifier_attributes_deep : typ -> typ

(** Remove all attributes relative to const, volatile and restrict attributes
    when building a C cast
*)
val type_remove_attributes_for_c_cast: typ -> typ

(** Remove all attributes relative to const, volatile and restrict attributes
    when building a logic cast
*)
val type_remove_attributes_for_logic_type: typ -> typ

(* ************************************************************************* *)
(** {2 Utils functions} *)
(* ************************************************************************* *)

(** Unroll a type until it exposes a non [TNamed]. Will collect all attributes
    appearing in [TNamed] and add them to the final type using
    {!Ast_attributes.type_add_attributes}.
*)
val unroll_type: typ -> typ

(** Same than {!unroll_type} but discard the final type attributes and only
    return its node. *)
val unroll_type_node: typ -> typ_node

(** Unroll typedefs, discarding all intermediate attribute. To be used only
    when one is interested in the shape of the type *)
val unroll_type_skel: typ -> typ_node

(** Unroll all the TNamed in a type (even under type constructors such as
    [TPtr], [TFun] or [TArray]. Does not unroll the types of fields in [TComp]
    types. Will collect all attributes *)
val unroll_type_deep: typ -> typ

(* ************************************************************************* *)
(** {2 Ghost Attribute} *)
(* ************************************************************************* *)

(** Add the ghost attribute to a type (does nothing if the type is alreay
    ghost).
*)
val type_add_ghost : typ -> typ

(** Check for ["ghost"] qualifier from the type of an l-value (do not follow
    pointer)
*)
val is_ghost_type : typ -> bool

(** Check if the received type is well-formed according to \ghost semantics, that is
    once the type is not ghost anymore, \ghost cannot appear again.
*)
val is_wellformed_ghost_type : typ -> bool
