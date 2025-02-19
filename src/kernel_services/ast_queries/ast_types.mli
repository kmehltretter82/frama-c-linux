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

(* TO REMOVE *)

val pp_typ_ref : (Format.formatter -> typ -> unit) ref

(* ************************************************************************* *)
(** {2 Type Attributes} *)
(* ************************************************************************* *)

(** Returns all the attributes contained in a type. This requires a traversal
    of the type structure, in case of composite, enumeration and named types *)
val get_attributes : typ -> attributes

(** Add some attributes to a type.
    [combine] explains how to combine attributes.
    Default is {!Ast_attributes.add_list}.
*)
val add_attributes :
  ?combine:(attribute list ->
            attributes -> attributes) ->
  attribute list -> typ -> typ

(** Does the type have the given attribute. Does
    not recurse through pointer types, nor inside function prototypes.
*)
val has_attribute : string -> typ -> bool

(** Does the type have the given qualifier. Handles the case of arrays, for
    which the qualifiers are actually carried by the type of the elements.
    It is always correct to call this function instead of {!has_attribute}.
    For l-values, both functions return the same results, as l-values cannot
    have array type.
*)
val has_qualifier : string -> typ -> bool

(** [has_attribute_memory_block attr t] is [true] iff at least one component of
    an object of type [t] has attribute [attr]. In other words, it searches
    for [attr] under aggregates, but not under pointers.
*)
val has_attribute_memory_block : string -> typ -> bool

(** Remove all attributes with the given names from a type. Note that this
    does not remove attributes from typedef and tag definitions, just from
    their uses (unfolding the type definition when needed).
    It only removes attributes of topmost type, i.e. does not
    recurse under pointers, arrays, ...
*)
val remove_attributes : string list -> typ -> typ

(** Same as {!remove_attributes}, but remove any existing attribute from
    the type.
*)
val remove_all_attributes : typ -> typ

(** Same as {!remove_attributes}, but recursively removes the given
    attributes from inner types as well. Mainly useful to check whether
    two types are equal modulo some attributes. See also
    {!Cil.typeDeepDropAllAttributes}, which will strip every single attribute
    from a type.
*)
val remove_attributes_deep : string list -> typ -> typ

(** Remove all attributes relative to const, volatile and restrict attributes. *)
val remove_qualifiers : typ -> typ

(** Remove also qualifiers under Ptr and Arrays. *)
val remove_qualifiers_deep : typ -> typ

(** Remove all attributes relative to const, volatile and restrict attributes
    when building a C cast
*)
val remove_attributes_for_c_cast : typ -> typ

(** Remove all attributes relative to const, volatile and restrict attributes
    when building a logic cast
*)
val remove_attributes_for_logic_type : typ -> typ

(* ************************************************************************* *)
(** {2 Utils functions} *)
(* ************************************************************************* *)

(** Unroll a type until it exposes a non [TNamed]. Will collect all attributes
    appearing in [TNamed] and add them to the final type using
    {!add_attributes}.
*)
val unroll_type : typ -> typ

(** Same than {!unroll_type} but discard the final type attributes and only
    return its node. *)
val unroll_type_node : typ -> typ_node

(** Unroll typedefs, discarding all intermediate attribute. To be used only
    when one is interested in the shape of the type *)
val unroll_type_skel : typ -> typ_node

(** Unroll all the TNamed in a type (even under type constructors such as
    [TPtr], [TFun] or [TArray]. Does not unroll the types of fields in [TComp]
    types. Will collect all attributes *)
val unroll_type_deep : typ -> typ

(** Expands logic type definitions. If the [unroll_typedef] flag is set to
    [true] (this is the default), C typedef will be expanded as well using
    {!Logic_const.unroll_ltdef}.
*)
val unroll_logic_type : ?unroll_typedef:bool -> logic_type -> logic_type

(* ************************************************************************* *)
(** {2 Ghost Attribute} *)
(* ************************************************************************* *)

(** Add the ghost attribute to a type (does nothing if the type is alreay
    ghost).
*)
val add_ghost : typ -> typ

(** Check for ["ghost"] qualifier from the type of an l-value (do not follow
    pointer)
*)
val is_ghost : typ -> bool

(** Check if the received type is well-formed according to \ghost semantics, that is
    once the type is not ghost anymore, \ghost cannot appear again.
*)
val is_wellformed_ghost : typ -> bool

(* ************************************************************************* *)
(** {2 Type checkers} *)
(* ************************************************************************* *)

(** is the given type "void"? *)
val is_void : typ -> bool

(** is the given type "void *"? *)
val is_void_ptr : typ -> bool

(** True if the argument is [_Bool]. *)
val is_bool : typ -> bool

(** True if the argument is a plain character type (but neither [signed char]
    nor [unsigned char]).
*)
val is_char : typ -> bool

(** True if the argument is a character type (i.e. plain, signed or unsigned). *)
val is_any_char : typ -> bool

(** True if the argument is a pointer to a plain character type (but neither
    [signed char] nor [unsigned char]).
*)
val is_char_ptr : typ -> bool

(** True if the argument is a pointer to a character type (i.e. plain, signed or
    unsigned).
*)
val is_any_char_ptr : typ -> bool

(** True if the argument is a pointer to a constant character type, e.g. a
    string literal.
*)
val is_char_const_ptr : typ -> bool

(** True if the argument is a short type (i.e. signed or unsigned). *)
val is_short : typ -> bool

(** True if the argument is an integral type (i.e. integer or enum). *)
val is_integral : typ -> bool

(** True if the argument is [intptr_t] (but _not_ its underlying integer type). *)
val is_intptr_t : typ -> bool

(** True if the argument is [uintptr_t] (but _not_ its underlying integer type). *)
val is_uintptr_t : typ -> bool

(** True if the argument is a floating point type. *)
val is_float : typ -> bool

(** True if the argument is a long double type. *)
val is_long_double : typ -> bool

(** True if the argument is an arithmetic type (i.e. integer, enum or floating
    point.
*)
val is_arithmetic : typ -> bool

(** True if the argument is a pointer type. *)
val is_ptr : typ -> bool

(** True if the argument is an integral or pointer type. *)
val is_integral_or_pointer : typ -> bool

(** True if the argument is an array type. *)
val is_array : typ -> bool

(** True if the argument is an array type without size. *)
val is_unsized_array : typ -> bool

(** True if the argument is a sized array type. *)
val is_sized_array : typ -> bool

(** True if the argument is an array of a character type (i.e. plain, signed or
    unsigned).
*)
val is_char_array : typ -> bool

(** True if the argument is an array of a character type (i.e. plain, signed or
    unsigned).
*)
val is_any_char_array : typ -> bool

(** True if the argument is a function type. *)
val is_fun : typ -> bool

(** True if the argument is a function pointer type. *)
val is_fun_ptr : typ -> bool

(** True if the argument is a scalar type (i.e. integral, enum, floating point
    or pointer.
*)
val is_scalar : typ -> bool

(** True if the argument is an object type (i.e. not a function type). *)
val is_object : typ -> bool

(** True if the argument is a struct. *)
val is_struct : typ -> bool

(** True if the argument is a union type. *)
val is_union : typ -> bool

(** True if the argument is a struct or union type. *)
val is_struct_or_union : typ -> bool

(** Check if a type is a transparent union, and return the first field. *)
val is_transparent_union : typ -> fieldinfo option

(** True if the argument denotes the type of [...] in a variadic function. *)
val is_variadic_list : typ -> bool

(* ************************************************************************* *)
(** {2 Type access} *)
(* ************************************************************************* *)

(** Returns the type of the array elements of the given type.
    @raise AbortFatal it is not an array type.
*)
val direct_element_type : typ -> typ

(** Returns the elements type using {!direct_element_type}, but if the resulting
    type is an array, recursively call {!element_type}.
*)
val element_type : typ -> typ

(** Returns the type directly pointed by the given type.
    @raise AbortFatal it is not a pointer type.
*)
val direct_pointed_type : typ -> typ

(** Returns the pointed type using {!direct_pointed_type}, but if the resulting
    type is an array, returns the element type instead using {!element_type}
*)
val pointed_type : typ -> typ

(** Returns the type of the array elements of the given type, and the size
    of the array, if any.
    @raise AbortFatal it is not an array type.
    @before Frama-C+dev In Cil this function applied {!Cil.constFoldToInt} on
    array's size and returned a [Z.t option].
*)
val array_elem_type_and_size : typ -> typ * exp option


(* ************************************************************************* *)
(** {2 Logic Type checkers} *)
(* ************************************************************************* *)

(** True if the argument is the type for reified C types. *)
val is_logic_typetag : logic_type -> bool

(** True if the argument is a boolean type, either integral C type or
    mathematical boolean one.
*)
val is_logic_boolean : logic_type -> bool

(** True if the argument is [_Bool] or [boolean]. *)
val is_logic_pure_boolean : logic_type -> bool

(** True if the argument is an integral type (i.e. integer or enum), either C or
    mathematical one.
*)
val is_logic_integral : logic_type -> bool

(** True if the argument is a floating point type. *)
val is_logic_float : logic_type -> bool

(** True if the argument is the logic 'real' type. *)
val is_logic_real : logic_type -> bool

(** True if the argument is a C floating point type or logic 'real' type. *)
val is_logic_real_or_float : logic_type -> bool

(** True if the argument is a logic arithmetic type (i.e. integer, enum or
    floating point, either C or mathematical one.
*)
val is_logic_arithmetic : logic_type -> bool

(** True if the argument is the logic function type. Expands the logic type
    definition if necessary.
*)
val is_logic_fun : logic_type -> bool

(** True if the argument is the logic function pointer type. Expands the logic
    type definition if necessary.
*)
val is_logic_fun_ptr : logic_type -> bool
