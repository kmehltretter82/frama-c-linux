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

(** This file contains attribute related types/functions/values.
    @since Frama-C+dev
    @before Frama-C+dev Most of these functions were in {!Cil}
*)

open Cil_types

(* **************************** *)
(** {2 Attributes lists/values} *)
(* **************************** *)

(** Name of the attribute that is automatically inserted (with an [AINT size]
    argument when querying the type of a field that is a bitfield.
*)
val bitfield_attribute_name : string

(** Name of the attribute that is inserted when generating a name for a varinfo
    representing an anonymous function parameter.
*)
val anonymous_attribute_name : string

(** Attribute identifying anonymous function parameters. *)
val anonymous_attribute : attribute

(** [const], [volatile], [restrict] and [ghost] attributes. *)
val qualifier_attributes : string list

(** Internal attributes of Frama-C.  *)
val fc_internal_attributes : string list

(** Qualifiers and internal attributes to remove when doing a C cast. *)
val cast_irrelevant_attributes : string list

(** Qualifiers and internal attributes to remove when doing a C cast. *)
val spare_attributes_for_c_cast : string list

(** Qualifiers and internal attributes to remove when doing a C cast. *)
val spare_attributes_for_logic_cast : string list

(** A block marked with this attribute is known to be a ghost else. *)
val frama_c_ghost_else : string

(** A varinfo marked with this attribute is known to be a ghost formal. *)
val frama_c_ghost_formal : string

(** A formal marked with this attribute is known to be a pointer to an
    object being initialized by the current function, which can thus assign
    any sub-object regardless of const status.
*)
val frama_c_init_obj : string

(** A field struct marked with this attribute is known to be mutable, i.e.
    it can be modified even on a const object.
*)
val frama_c_mutable : string

(** A block marked with this attribute is known to be inlined, i.e.
    it replaces a call to an inline function.
*)
val frama_c_inlined : string

(* ***************************** *)
(** {2 Attributes manipulations} *)
(* ***************************** *)

(** Return the name of an attribute. *)
val get_name : attribute -> string

(** Add an attribute. Maintains the attributes in sorted order of the second
    argument. The attribute is not added if it is already there.
*)
val add : attribute -> attributes -> attributes

(** Add a list of attributes. Maintains the attributes in sorted order. The
    second argument must be sorted, but not necessarily the first.
*)
val add_list : attributes -> attributes -> attributes

(** Remove all attributes with the given name. Maintains the attributes in
    sorted order.
*)
val drop : string -> attributes -> attributes

(** Remove all attributes with names appearing in the string list.
    Maintains the attributes in sorted order.
*)
val drop_list : string list -> attributes -> attributes

(** [replace_params name params al] will {!drop} all the attributes named [name]
    in [al] and {!add} a new attribute [(name, params)] in the list.
*)
val replace_params : string -> attrparam list -> attributes -> attributes

(** True if the named attribute appears in the attribute list. The list of
    attributes must be sorted.
*)
val contains : string -> attributes -> bool

(** Return the list of parameters associated to an attribute. The list is empty
    if there is no such attribute or it has no parameters at all.
*)
val find_params : string -> attributes -> attrparam list

(** Retain attributes with the given name. *)
val filter : string -> attributes -> attributes

(* **************************************** *)
(** {2 Attributes classes and registration} *)
(* **************************************** *)

type attribute_class =
  (** Attribute of a name. If argument is true and we are on MSVC then
      the attribute is printed using __declspec as part of the storage
      specifier  *)
  | AttrName of bool

  (** Attribute of a function type. If argument is true and we are on
      MSVC then the attribute is printed just before the function name *)
  | AttrFunType of bool

  (** Attribute of a type *)
  | AttrType

  (** Attribute of a statement or a block *)
  | AttrStmt

  (** Attribute that does not correspond to either of the above classes and is
      ignored by functions {!get_attribute_class} and {!partition_attributes}. *)
  | AttrIgnored

(** Table containing all registered attributes. *)
val known_table : (string, attribute_class) Hashtbl.t

(** Add a new attribute with a specified class *)
val register : attribute_class -> string -> unit

(** Register a list of attributes with a given class. *)
val register_list : attribute_class -> string list ->  unit

(** Remove an attribute previously registered. *)
val remove : string -> unit

(** Return the class of an attribute. The class `default' is returned for
    unknown and ignored attributes.
*)
val get_class : default:attribute_class -> string -> attribute_class

(** [is_known_attribute attrname] returns true if the attribute named
    [attrname] is known by Frama-C.
*)
val is_known : string -> bool

(** Partition the attributes into classes: name attributes, function type and
    type attributes. Unknown and ignored attributes are returned in the
    `default` attribute class.
*)
val partition : default:attribute_class -> attributes ->
  attributes * (* AttrName *)
  attributes * (* AttrFunType *)
  attributes   (* AttrType *)

(* **************************************** *)
(** {2 Utility functions} *)
(* **************************************** *)

(** Retain attributes corresponding to type qualifiers (6.7.3) *)
val filter_qualifiers : attributes -> attributes

(** Given some attributes on an array type, split them into those that belong
    to the type of the elements of the array (currently, qualifiers such as
    const and volatile), and those that must remain on the array, in that
    order.
*)
val split_array_attributes : attributes -> attributes * attributes

(** Separate out the storage-modifier name attributes *)
val split_storage_modifiers : attributes -> attributes * attributes
