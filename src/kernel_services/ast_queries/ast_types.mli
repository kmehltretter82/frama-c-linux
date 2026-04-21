(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** This file contains types related types/functions/values.
    @since 31.0-Gallium
    @before 31.0-Gallium Most of these functions were in {!Cil}
*)

open Cil_types

(* ************************************************************************* *)
(** {2 Type Attributes} *)
(* ************************************************************************* *)

(** Returns all the attributes contained in a type. This requires a traversal
    of the type structure, in case of composite, enumeration and named types *)
val get_attributes : typ -> attributes

(** Add some attributes to a type. [push_qualifiers] determines if type
    qualifiers are pushed to the elements type. It defaults to [true] and
    should not be set to [false] unless you known what you are doing. In
    Frama-C this is useful for formals (see C11 6.7.6.3#7), so
    [push_qualifiers] is turned off when typing array formals before they are
    changed into pointers.

    @before 31.0-Gallium In Cil [push_qualifiers] was not present, which caused a
    bug in cabs2cil. Also [combine] was present and allowed to chose the
    function used to combine attributes, now it only uses
    {!Ast_attributes.add_list}.
*)
val add_attributes : ?push_qualifiers:bool -> attribute list -> typ -> typ

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
val unroll : typ -> typ

(** Same than {!unroll} but discard the final type attributes and only
    return its node. *)
val unroll_node : typ -> typ_node

(** Unroll typedefs, discarding all intermediate attribute. To be used only
    when one is interested in the shape of the type *)
val unroll_skel : typ -> typ_node

(** Unroll all the TNamed in a type (even under type constructors such as
    [TPtr], [TFun] or [TArray]. Does not unroll the types of fields in [TComp]
    types. Will collect all attributes *)
val unroll_deep : typ -> typ

(** Same than {!unroll_deep} but discard the final type attributes and only
    return its node. *)
val unroll_deep_node : typ -> typ_node

(* ************************************************************************* *)
(** {2 Const Attribute} *)
(* ************************************************************************* *)

(** Check for ["const"] qualifier from the type of an l-value using
    {!has_attribute_memory_block}.
*)
val is_const : typ -> bool

(* ************************************************************************* *)
(** {2 Volatile Attribute} *)
(* ************************************************************************* *)

(** Check for ["volatile"] qualifier from the type of an l-value using
    {!has_attribute_memory_block}.
*)
val is_volatile : typ -> bool

(* ************************************************************************* *)
(** {2 Ghost Attribute} *)
(* ************************************************************************* *)

(** Add the ghost attribute to a type (does nothing if the type is already
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

(** True if the argument is an array of wchar_t. Can only be used after
    Machdep has been set.
    @since 32.0-Germanium
*)
val is_wchar_array : typ -> bool

(** True if the argument is a function type. *)
val is_fun : typ -> bool

(** True if the argument is a variadic function type.
    @since 33.0-Arsenic
*)
val is_variadic : typ -> bool

(** True if the argument is a function pointer type. *)
val is_fun_ptr : typ -> bool

(** True if the argument is a pointer {i or} a function type.
    @since 33.0-Arsenic
*)
val is_fun_or_ptr : typ -> bool

(** True if the argument is a scalar type (i.e. integral, enum, floating point
    or pointer.
*)
val is_scalar : typ -> bool

(** True if the argument is an object type (i.e. not a function type). *)
val is_object : typ -> bool

(** True if the argument is an object pointer type.
    @since 33.0-Arsenic
*)
val is_object_ptr : typ -> bool

(** True if the argument is a struct. *)
val is_struct : typ -> bool

(** True if the argument is a type that directly (modulo name) contains a
    bitfield.
    @since 32.0-Germanium
*)
val has_bitfield : typ -> bool

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
    @raise AbortFatal if argument is not an array type.
*)
val direct_array_element : typ -> typ

(** Returns the elements type using {!direct_element_type}, but if the resulting
    type is an array, recursively call {!element_type}.
*)
val array_element : typ -> typ


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
    @before 31.0-Gallium In Cil this function applied {!Cil.constFoldToInt} on
    array's size and returned a [Z.t option].
*)
val array_elem_type_and_size : typ -> typ * exp option


(* ************************************************************************* *)
(** {2 Logic Type checkers} *)
(* ************************************************************************* *)


(* ************************************************************************* *)
(** {2 Logic Type utilities} *)
(* ************************************************************************* *)

(** @since Frama-C+dev *)
module Acsl : sig

  (** instantiate type variables in a logic type.
      @before 18.0-Argon was in {!Logic_utils}
      @before Frama-C+dev was in {!Logic_const}
  *)
  val instantiate:
    (string * logic_type) list ->
    logic_type -> logic_type

  (** @return [true] if the logic type definition can be expanded.
      @before Frama-C+dev was in {!Logic_const}
  *)
  val is_unrollable_ltdef : logic_type_info -> bool

  (** expands logic type definitions only.
      To expands both logic part and C part, uses {!Ast_types.Acsl.unroll_logic}.
      @before Frama-C+dev was in {!Logic_const}
  *)
  val unroll_ltdef: logic_type -> logic_type

  (** Expands logic type definitions. If the [unroll_typedef] flag is set to
      [true] (this is the default), C typedef will be expanded as well using
      {!Ast_types.Acsl.unroll_ltdef}.
  *)
  val unroll_logic: ?unroll_typedef:bool -> logic_type -> logic_type

  (** Check for ["volatile"] qualifier from a logic type using {!is_volatile}. *)
  val is_logic_volatile: logic_type -> bool

  (** True if the argument is the type for reified C types. *)
  val is_logic_typetag: logic_type -> bool

  (** True if the argument is a boolean type, either integral C type
      or mathematical boolean one.
  *)
  val is_logic_boolean: logic_type -> bool

  (** True if the argument is [_Bool] or [boolean]. *)
  val is_logic_pure_boolean: logic_type -> bool

  (** True if the argument is an integral type (i.e. integer or enum), either C
      or mathematical one.
  *)
  val is_logic_integral: logic_type -> bool

  (** True if the argument is a floating point type. *)
  val is_logic_float: logic_type -> bool

  (** True if the argument is the logic 'real' type. *)
  val is_logic_real: logic_type -> bool

  (** True if the argument is a C floating point type or logic 'real' type. *)
  val is_logic_real_or_float: logic_type -> bool

  (** True if the argument is a logic arithmetic type (i.e. integer, enum or
      floating point, either C or mathematical one.
  *)
  val is_logic_arithmetic: logic_type -> bool

  (** [is_logic_ctype test typ] is [false] for pure logic types and the result
      of test for C types.
      @before Frama-C+dev was in {!Logic_const}
  *)
  val is_logic_ctype: (typ -> bool) -> logic_type -> bool

  (** True if the argument is a pointer type. Expands the logic type
      definition if necessary.
  *)
  val is_logic_ptr: logic_type -> bool

  (** True if the argument is the logic function type. Expands the logic type
      definition if necessary.
  *)
  val is_logic_fun: logic_type -> bool

  (** True if the argument is the logic function pointer type. Expands the logic
      type definition if necessary.
  *)
  val is_logic_fun_ptr: logic_type -> bool

  (** True if the argument is a pointer {i or} function type.
      Expands the logic type definition if necessary.
  *)
  val is_logic_fun_or_ptr: logic_type -> bool

  (** returns [true] if the type is a list<t>.
      @before Frama-C+dev was in {!Logic_const}
  *)
  val is_plain_list: logic_type -> bool

  (** [make_list t] returns the type list<[t]>.
      @before Frama-C+dev was in {!Logic_const}
  *)
  val make_list: logic_type -> logic_type

  (** returns the type of elements of a list type.
      @raise Failure if the input type is not a list type.
      @before Frama-C+dev was in {!Logic_const}
  *)
  val list_element: logic_type -> logic_type

  (** returns [true] if the type is a set<t>.
      @before Frama-C+dev was in {!Logic_const}
  *)
  val is_plain_set: logic_type -> bool

  (** converts a type into the corresponding set type if needed. Does nothing
      if the argument is already a set type.
      @before Frama-C+dev was in {!Logic_const}
  *)
  val make_set: logic_type -> logic_type

  (** [set_conversion ty1 ty2] returns a set type as soon as [ty1] and/or [ty2]
      is a set. Elements have type [ty1], or the type of the elements of [ty1] if
      it is itself a set-type (i.e. we do not build set of sets that way).
      @before Frama-C+dev was in {!Logic_const}
  *)
  val set_conversion: logic_type -> logic_type -> logic_type

  (** returns the type of elements of a set type.
      @raise Failure if the input type is not a set type.
      @before Frama-C+dev was in {!Logic_const}
  *)
  val set_element: logic_type -> logic_type

  (** [plain_or_set f t] applies [f] to [t] or to the type of elements of [t]
      if it is a set type.
      @before Frama-C+dev was in {!Logic_const}
  *)
  val plain_or_set: (logic_type -> 'a) -> logic_type -> 'a

  (** [transform_element f t] is the same as
      [set_conversion (plain_or_set f t) t]
      @before Frama-C+dev was in {!Logic_const}
  *)
   val transform_element: (logic_type -> logic_type) -> logic_type -> logic_type

  (** [true] if the argument is not a set type.
      @before Frama-C+dev was in {!Logic_const}
   *)
  val is_plain: logic_type -> bool

  (** [make_arrow args rt] returns a [rt] if [args] is empty or the
      corresponding [Larrow] type.
      @before Frama-C+dev was in {!Logic_const}
  *)
  val make_arrow: logic_var list -> logic_type -> logic_type

  (** @return true if the argument is the boolean type.
      @before Frama-C+dev was in {!Logic_const}
  *)
  val is_boolean: logic_type -> bool

  (** {3 tests and extraction of element type}
      @before 31.0-Gallium these function were in {!Logic_typing}
  *)

  (** {4 tests for an individual (non set) type}
      [plain_xxx t] returns [true] iff [t] is a [xxx]
      @before 31.0-Gallium these functions were not exported
  *)

  (** @before Frama-C+dev was in {!Logic_utils} *)
  val is_plain_arithmetic: Cil_types.logic_type -> bool

  (** @before Frama-C+dev was in {!Logic_utils} *)
  val is_plain_integral: Cil_types.logic_type -> bool

  (** @before Frama-C+dev was in {!Logic_utils} *)
  val is_plain_fun_ptr: Cil_types.logic_type -> bool

  (** @before Frama-C+dev was in {!Logic_utils} *)
  val is_plain_array: Cil_types.logic_type -> bool

  (** @before Frama-C+dev was in {!Logic_utils} *)
  val is_plain_pointer: Cil_types.logic_type -> bool

  (** {4 tests for potential sets}
      [is_xxx t] returns true iff [t] is a [xxx] _or_ a set of [xxx]
  *)

  (** @before Frama-C+dev was in {!Logic_utils} *)
  val is_arithmetic_type: Cil_types.logic_type -> bool

  (** @before Frama-C+dev was in {!Logic_utils} *)
  val is_integral_type: Cil_types.logic_type -> bool

  (** @before Frama-C+dev was in {!Logic_utils} *)
  val is_fun_ptr: Cil_types.logic_type -> bool

  (** @before Frama-C+dev was in {!Logic_utils} *)
  val is_array: Cil_types.logic_type -> bool

  (** @before Frama-C+dev was in {!Logic_utils} *)
  val is_pointer: Cil_types.logic_type -> bool

  (** {4 sets and lists} *)

  (** @before Frama-C+dev was in {!Logic_utils} *)
  val is_list: Cil_types.logic_type -> bool

  (** @before Frama-C+dev was in {!Logic_utils} *)
  val is_set: Cil_types.logic_type -> bool

  (** returns the type of the element pointed to by the type. If the
      source type is a set of pointers, returns a set of elements.
  *)
  (* val pointed: logic_type -> logic_type *)

  (** same as {!type_of_pointed} but for arrays (or set of arrays). *)
  (*val array_element: logic_type -> logic_type*)

  (** {3 Predefined tests over types} *)

  (** [is_logic test typ] is [false] for pure logic types and the result
      of test for C types.
      In case of a set type, the function tests the element type.
      @before Frama-C+dev was in {!Logic_utils}
  *)
  val is_logic: (typ -> bool) -> logic_type -> bool

  (** @before Frama-C+dev was in {!Logic_utils} *)
  val is_logic_array : logic_type -> bool

  (** @before Frama-C+dev was in {!Logic_utils} *)
  val is_logic_char : logic_type -> bool

  (** @before Frama-C+dev was in {!Logic_utils}
  *)
  val is_logic_any_char : logic_type -> bool

  (** @before Frama-C+dev was in {!Logic_utils} *)
  val is_logic_void : logic_type -> bool

  (** @before Frama-C+dev was in {!Logic_utils} *)
  val is_logic_pointer : logic_type -> bool

  (** @before Frama-C+dev was in {!Logic_utils} *)
  val is_logic_void_pointer : logic_type -> bool

  (** {3 Type conversions} *)

  (** @return the equivalent C type.
      @raise Failure if the type is purely logical
      @before Frama-C+dev was in {!Logic_utils}
  *)
  val logic_ctype : logic_type -> typ

  (** transforms an array into pointer. *)
  (* val array_to_ptr : logic_type -> logic_type *)

  (** removes qualifiers if logic_type is a C type, identity otherwise.
      @before Frama-C+dev was in {!Logic_utils}
  *)
  val remove_qualifiers: logic_type -> logic_type

  (** [numeric_coerce typ t] returns a term with the same value as [t]
      and of type [typ].  [typ] which should be [Linteger] or
      [Lreal]. [numeric_coerce] tries to avoid unnecessary type conversions
      in [t]. In particular, [numeric_coerce (int)cst Linteger], where [cst]
      fits in int will be directly [cst], without any coercion.

      Also coerce recursively the sub-terms of t-set expressions
      (range, union, inter and comprehension) and lift the associated
      set type.

      @before 21.0-Scandium was ambiguous (coercion vs. conversion).
  *)
  (*val numeric_coerce: logic_type -> term -> term*)

  (** @before Frama-C+dev was in {!Logic_utils} *)
  val is_same : logic_type -> logic_type -> bool

  (** @before Frama-C+dev was in {!Logic_typing} *)
  val ctype_of_pointed: logic_type -> typ

  (** @before Frama-C+dev was in {!Logic_typing} *)
  val ctype_of_array_elem: logic_type -> typ

  (** @before Frama-C+dev was in {!Logic_typing} *)
  val arithmetic_conversion:
    Cil_types.logic_type -> Cil_types.logic_type -> Cil_types.logic_type
end





(** Expands logic type definitions. If the [unroll_typedef] flag is set to
    [true] (this is the default), C typedef will be expanded as well using
    {!Ast_types.Acsl.unroll_ltdef}.
*)
val unroll_logic : ?unroll_typedef:bool -> logic_type -> logic_type
[@@deprecated "Use Ast_types.Acsl.unroll_logic instead"]
[@@migrate { repl = Rel.Acsl.unroll_logic }]

(** Returns the type of the array elements of the given type.
    @raise AbortFatal it is not an array type.
*)
val direct_element_type : typ -> typ
[@@deprecated "Use Ast_types.direct_array_element instead"]
[@@migrate { repl = Rel.direct_array_element }]

(** Returns the elements type using {!direct_element_type}, but if the resulting
    type is an array, recursively call {!element_type}.
*)
val element_type : typ -> typ
[@@deprecated "Use Ast_types.array_element instead"]
[@@migrate { repl = Rel.array_element }]

(** Check for ["volatile"] qualifier from a logic type using {!is_volatile}. *)
val is_logic_volatile : logic_type -> bool
[@@deprecated "Use Ast_types.Acsl.is_logic_volatile instead"]
[@@migrate { repl = Rel.Acsl.is_logic_volatile }]

(** True if the argument is the type for reified C types. *)
val is_logic_typetag : logic_type -> bool
[@@deprecated "Use Ast_types.Acsl.is_logic_typetag instead"]
[@@migrate { repl = Rel.Acsl.is_logic_typetag }]

(** True if the argument is a boolean type, either integral C type or
    mathematical boolean one.
*)
val is_logic_boolean : logic_type -> bool
[@@deprecated "Use Ast_types.Acsl.is_logic_boolean instead"]
[@@migrate { repl = Rel.Acsl.is_logic_boolean }]

(** True if the argument is [_Bool] or [boolean]. *)
val is_logic_pure_boolean : logic_type -> bool
[@@deprecated "Use Ast_types.Acsl.is_logic_pure_boolean instead"]
[@@migrate { repl = Rel.Acsl.is_logic_pure_boolean }]

(** True if the argument is an integral type (i.e. integer or enum), either C or
    mathematical one.
*)
val is_logic_integral : logic_type -> bool
[@@deprecated "Use Ast_types.Acsl.is_logic_integral instead"]
[@@migrate { repl = Rel.Acsl.is_logic_integral }]

(** True if the argument is a floating point type. *)
val is_logic_float : logic_type -> bool
[@@deprecated "Use Ast_types.Acsl.is_logic_float instead"]
[@@migrate { repl = Rel.Acsl.is_logic_float }]

(** True if the argument is the logic 'real' type. *)
val is_logic_real : logic_type -> bool
[@@deprecated "Use Ast_types.Acsl.is_logic_real instead"]
[@@migrate { repl = Rel.Acsl.is_logic_real }]

(** True if the argument is a C floating point type or logic 'real' type. *)
val is_logic_real_or_float : logic_type -> bool
[@@deprecated "Use Ast_types.Acsl.is_logic_real_or_float instead"]
[@@migrate { repl = Rel.Acsl.is_logic_real_or_float }]

(** True if the argument is a logic arithmetic type (i.e. integer, enum or
    floating point, either C or mathematical one.
*)
val is_logic_arithmetic : logic_type -> bool
[@@deprecated "Use Ast_types.Acsl.is_logic_arithmetic instead"]
[@@migrate { repl = Rel.Acsl.is_logic_arithmetic }]

(** True if the argument is a pointer type. Expands the logic type
    definition if necessary.
    @since 33.0-Arsenic
*)
val is_logic_ptr : logic_type -> bool
[@@deprecated "Use Ast_types.Acsl.is_logic_ptr instead"]
[@@migrate { repl = Rel.Acsl.is_logic_ptr }]

(** True if the argument is the logic function type. Expands the logic type
    definition if necessary.
*)
val is_logic_fun : logic_type -> bool
[@@deprecated "Use Ast_types.Acsl.is_logic_fun instead"]
[@@migrate { repl = Rel.Acsl.is_logic_fun }]

(** True if the argument is the logic function pointer type. Expands the logic
    type definition if necessary.
*)
val is_logic_fun_ptr : logic_type -> bool
[@@deprecated "Use Ast_types.Acsl.is_logic_fun_ptr instead"]
[@@migrate { repl = Rel.Acsl.is_logic_fun_ptr }]

(** True if the argument is a pointer {i or} function type.
    Expands the logic type definition if necessary.
    @since 33.0-Arsenic
*)
val is_logic_fun_or_ptr : logic_type -> bool
[@@deprecated "Use Ast_types.Acsl.is_logic_fun_or_ptr instead"]
[@@migrate { repl = Rel.Acsl.is_logic_fun_or_ptr }]
