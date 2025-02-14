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

(** This file contains attribute related types/functions/values. *)

open Cil_types

(* Construct sorted lists of attributes *)
let attribute_name (an, _) =
  Extlib.strip_underscore an

let has_attribute an al =
  let an = Extlib.strip_underscore an in
  List.exists (fun a -> attribute_name a = an) al

(* Attributes are added as they are (e.g. if we add ["__attr"] and then ["attr"]
   both are added). When checking for the presence of an attribute [x] or trying
   to remove it, underscores are removed at the beginning and the end of the
   attribute for both the [x] attribute and the attributes of the list. For
   example, if have a call:

   drop_attribute "__const" [ Attr("const", []) ; Attr("__const", []) ; Attr("__const__", []) ]

   The result is [].
*)
let add_attribute ((an, _) as a) al =
  let rec insert_sorted = function
    | [] -> [a]
    | (((an0, _) as a0) :: rest) as l ->
      if an < an0 then a :: l
      else if Cil_datatype.Attribute.equal a a0 then l (* Do not add if already in there *)
      else a0 :: insert_sorted rest (* Make sure we see all attributes with
                                     * this name *)
  in
  insert_sorted al

(* The second attribute list is sorted *)
let add_attributes al0 al =
  if al0 == [] then
    al
  else
    List.fold_left (fun acc a -> add_attribute a acc) al al0

let drop_attribute an al =
  let an = Extlib.strip_underscore an in
  List.filter (fun a -> attribute_name a <> an) al

let rec drop_attributes anl al =
  match al with
  | [] -> []
  | a :: q ->
    let q' = drop_attributes anl q in
    if List.mem (attribute_name a) anl then
      q' (* drop this attribute *)
    else
    if q' == q then al (* preserve sharing *) else a :: q'

let find_attribute an al =
  let an = Extlib.strip_underscore an in
  List.fold_left (fun acc ((_, param) as a) ->
      if attribute_name a = an then param @ acc else acc
    ) [] al

let filter_attributes an al =
  let an = Extlib.strip_underscore an in
  List.filter (fun a -> attribute_name a = an) al

(**************************************)
(* Attribute registration and classes *)
(**************************************)

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

(* This table contains the mapping of predefined attributes to classes.
 * Extend this table with more attributes as you need. This table is used to
 * determine how to associate attributes with names or type during cabs2cil
 * conversion *)
let attribute_hash : (string, attribute_class) Hashtbl.t = Hashtbl.create 59

let register_attribute ac an =
  if Hashtbl.mem attribute_hash an then begin
    let pp fmt c =
      match c with
      | AttrName b -> Format.fprintf fmt "(AttrName %B)" b
      | AttrFunType b -> Format.fprintf fmt "(AttrFunType %B)" b
      | AttrType -> Format.fprintf fmt "AttrType"
      | AttrIgnored -> Format.fprintf fmt "AttrIgnored"
      | AttrStmt -> Format.fprintf fmt "AttrStmt"
    in
    Kernel.warning
      "Replacing existing class for attribute %s: was %a, now %a"
      an pp (Hashtbl.find attribute_hash an) pp ac
  end;
  Hashtbl.replace attribute_hash an ac

let register_attributes ac al =
  List.iter (register_attribute ac) al

let remove_attribute = Hashtbl.remove attribute_hash

let get_attribute_class ~default name =
  match Hashtbl.find attribute_hash name with
  | exception Not_found -> default
  | AttrIgnored -> default
  | ac -> ac

let is_known_attribute = Hashtbl.mem attribute_hash

let partition_attributes
    ~(default:attribute_class)
    (attrs:  attribute list) :
  attribute list * attribute list * attribute list =
  let rec loop (n,f,t) = function
    | [] -> n, f, t
    | ((an, _) as a) :: rest ->
      match get_attribute_class ~default an with
        AttrName _ -> loop (add_attribute a n, f, t) rest
      | AttrFunType _ ->
        loop (n, add_attribute a f, t) rest
      | AttrType -> loop (n, f, add_attribute a t) rest
      | AttrStmt ->
        Kernel.warning "unexpected statement attribute %s" an;
        loop (n,f,t) rest
      | AttrIgnored -> loop (n, f, t) rest
  in
  loop ([], [], []) attrs

(* Registering some attributes. *)

let () =
  register_attributes (AttrName false)
    [ "section"; "constructor"; "destructor"; "unused"; "used"; "weak";
      "no_instrument_function"; "alias"; "no_check_memory_usage";
      "exception"; "model"; "aconst";
      (* Gcc uses this to specify the name to be used in assembly for a global  *)
      "asm" ]

let () =
  (* Now come the MSVC declspec attributes *)
  register_attributes (AttrName true)
    [ "thread"; "naked"; "dllimport"; "dllexport"; "selectany"; "allocate";
      "nothrow"; "novtable"; "property"; "uuid"; "align" ]

let () =
  register_attributes (AttrFunType false)
    [ "format"; "regparm"; "longcall"; "noinline"; "always_inline" ]

let () =
  register_attributes (AttrFunType true)
    [ "stdcall";"cdecl"; "fastcall"; "noreturn" ]

let () = register_attributes AttrType [ "mode" ]

let () =
  (* GCC label and statement attributes. *)
  register_attributes AttrStmt
    [ "hot"; "cold"; "fallthrough"; "assume"; "musttail" ]

let bitfield_attribute_name = "FRAMA_C_BITFIELD_SIZE"
let () = register_attribute AttrType bitfield_attribute_name

let anonymous_attribute_name = "fc_anonymous"
let () = register_attribute AttrIgnored anonymous_attribute_name

let anonymous_attribute = (anonymous_attribute_name, [])

let qualifier_attributes = [ "const"; "restrict"; "volatile"; "ghost" ]
let () = register_attributes AttrType qualifier_attributes

let fc_internal_attributes = ["declspec"; "arraylen"; "fc_stdlib"]
let () = register_attributes AttrIgnored fc_internal_attributes

let cast_irrelevant_attributes = ["visibility"]
let () = register_attributes AttrType cast_irrelevant_attributes

let spare_attributes_for_c_cast = fc_internal_attributes @ qualifier_attributes

let spare_attributes_for_logic_cast = spare_attributes_for_c_cast

let frama_c_ghost_else = "fc_ghost_else"
let () = register_attribute AttrStmt frama_c_ghost_else

let frama_c_ghost_formal = "fc_ghost_formal"
let () = register_attribute (AttrName false) frama_c_ghost_formal

let frama_c_init_obj = "fc_initialized_object"
let () = register_attribute (AttrName false) frama_c_init_obj

let frama_c_mutable = "fc_mutable"
let () = register_attribute (AttrName false) frama_c_mutable

let frama_c_inlined = "fc_inlined"
let () = register_attribute (AttrFunType false) frama_c_inlined

(* Forward declaration from Cil_datatype. *)

let () =
  Cil_datatype.drop_non_logic_attributes :=
    drop_attributes spare_attributes_for_logic_cast

let () =
  Cil_datatype.drop_fc_internal_attributes :=
    drop_attributes fc_internal_attributes

let () =
  Cil_datatype.drop_unknown_attributes :=
    let is_annot_or_known_attr (name, _) =
      is_known_attribute name
    in
    (fun attributes -> List.filter is_annot_or_known_attr attributes)

(**********************)
(* Utility functions  *)
(**********************)

let filter_qualifier_attributes al =
  List.filter (fun a -> List.mem (attribute_name a) qualifier_attributes) al

let split_array_attributes al =
  List.partition (fun a -> List.mem (attribute_name a) qualifier_attributes) al

let split_storage_modifier al =
  let isstoragemod ((an, _) : attribute) : bool =
    try
      match Hashtbl.find attribute_hash an with
      | AttrName issm -> issm
      | _ -> false
    with Not_found -> false
  in
  let stom, rest = List.partition isstoragemod al in
  if not (Machine.msvcMode ()) then stom, rest
  else
    (* Put back the declspec. Put it without the leading __ since these will
     * be added later *)
    let stom' =
      List.map (fun (an, args) -> ("declspec", [ACons(an, args)])) stom
    in
    stom', rest
