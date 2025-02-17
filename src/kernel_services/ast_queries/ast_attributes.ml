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
let get_name (an, _) =
  Extlib.strip_underscore an

(* Attributes are added as they are (e.g. if we add ["__attr"] and then ["attr"]
   both are added). When checking for the presence of an attribute [x] or trying
   to remove it, underscores are removed at the beginning and the end of the
   attribute for both the [x] attribute and the attributes of the list. For
   example, if have a call:

   drop_attribute "__const" [ Attr("const", []) ; Attr("__const", []) ; Attr("__const__", []) ]

   The result is [].
*)
let add ((an, _) as a) al =
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
let add_list al0 al =
  if al0 == [] then
    al
  else
    List.fold_left (fun acc a -> add a acc) al al0

let drop an al =
  let an = Extlib.strip_underscore an in
  List.filter (fun a -> get_name a <> an) al

let rec drop_list anl al =
  match al with
  | [] -> []
  | a :: q ->
    let q' = drop_list anl q in
    if List.mem (get_name a) anl then
      q' (* drop this attribute *)
    else
    if q' == q then al (* preserve sharing *) else a :: q'

let replace_params name params al =
  add (name, params) (drop name al)

let contains an al =
  let an = Extlib.strip_underscore an in
  List.exists (fun a -> get_name a = an) al

let find_params an al =
  let an = Extlib.strip_underscore an in
  List.fold_left (fun acc ((_, param) as a) ->
      if get_name a = an then param @ acc else acc
    ) [] al

let filter an al =
  let an = Extlib.strip_underscore an in
  List.filter (fun a -> get_name a = an) al

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
      ignored by functions {!get_class} and {!partition}. *)
  | AttrIgnored

(* This table contains the mapping of predefined attributes to classes.
 * Extend this table with more attributes as you need. This table is used to
 * determine how to associate attributes with names or type during cabs2cil
 * conversion *)
let known_table : (string, attribute_class) Hashtbl.t = Hashtbl.create 59

let register ac an =
  if Hashtbl.mem known_table an then begin
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
      an pp (Hashtbl.find known_table an) pp ac
  end;
  Hashtbl.replace known_table an ac

let register_list ac al =
  List.iter (register ac) al

let remove = Hashtbl.remove known_table

let get_class ~default name =
  match Hashtbl.find known_table name with
  | exception Not_found -> default
  | AttrIgnored -> default
  | ac -> ac

let is_known = Hashtbl.mem known_table

let partition
    ~(default:attribute_class)
    (attrs:  attribute list) :
  attribute list * attribute list * attribute list =
  let rec loop (n,f,t) = function
    | [] -> n, f, t
    | ((an, _) as a) :: rest ->
      match get_class ~default an with
        AttrName _ -> loop (add a n, f, t) rest
      | AttrFunType _ ->
        loop (n, add a f, t) rest
      | AttrType -> loop (n, f, add a t) rest
      | AttrStmt ->
        Kernel.warning "unexpected statement attribute %s" an;
        loop (n,f,t) rest
      | AttrIgnored -> loop (n, f, t) rest
  in
  loop ([], [], []) attrs

(* Registering some attributes. *)

let () =
  register_list (AttrName false)
    [ "section"; "constructor"; "destructor"; "unused"; "used"; "weak";
      "no_instrument_function"; "alias"; "no_check_memory_usage";
      "exception"; "model"; "aconst";
      (* Gcc uses this to specify the name to be used in assembly for a global  *)
      "asm" ]

let () =
  (* Now come the MSVC declspec attributes *)
  register_list (AttrName true)
    [ "thread"; "naked"; "dllimport"; "dllexport"; "selectany"; "allocate";
      "nothrow"; "novtable"; "property"; "uuid"; "align" ]

let () =
  register_list (AttrFunType false)
    [ "format"; "regparm"; "longcall"; "noinline"; "always_inline" ]

let () =
  register_list (AttrFunType true)
    [ "stdcall";"cdecl"; "fastcall"; "noreturn" ]

let () = register_list AttrType [ "mode" ]

let () =
  (* GCC label and statement attributes. *)
  register_list AttrStmt
    [ "hot"; "cold"; "fallthrough"; "assume"; "musttail" ]

let bitfield_attribute_name = "FRAMA_C_BITFIELD_SIZE"
let () = register AttrType bitfield_attribute_name

let anonymous_attribute_name = "fc_anonymous"
let () = register AttrIgnored anonymous_attribute_name

let anonymous_attribute = (anonymous_attribute_name, [])

let qualifier_attributes = [ "const"; "restrict"; "volatile"; "ghost" ]
let () = register_list AttrType qualifier_attributes

let fc_internal_attributes = ["declspec"; "arraylen"; "fc_stdlib"]
let () = register_list AttrIgnored fc_internal_attributes

let cast_irrelevant_attributes = ["visibility"]
let () = register_list AttrType cast_irrelevant_attributes

let spare_attributes_for_c_cast = fc_internal_attributes @ qualifier_attributes

let spare_attributes_for_logic_cast = spare_attributes_for_c_cast

let frama_c_ghost_else = "fc_ghost_else"
let () = register AttrStmt frama_c_ghost_else

let frama_c_ghost_formal = "fc_ghost_formal"
let () = register (AttrName false) frama_c_ghost_formal

let frama_c_init_obj = "fc_initialized_object"
let () = register (AttrName false) frama_c_init_obj

let frama_c_mutable = "fc_mutable"
let () = register (AttrName false) frama_c_mutable

let frama_c_inlined = "fc_inlined"
let () = register (AttrFunType false) frama_c_inlined

(* Forward declaration from Cil_datatype. *)

let () =
  Cil_datatype.drop_non_logic_attributes :=
    drop_list spare_attributes_for_logic_cast

let () =
  Cil_datatype.drop_fc_internal_attributes :=
    drop_list fc_internal_attributes

let () =
  Cil_datatype.drop_unknown_attributes :=
    let is_annot_or_known_attr (name, _) =
      is_known name
    in
    (fun attributes -> List.filter is_annot_or_known_attr attributes)

(**********************)
(* Utility functions  *)
(**********************)

let filter_qualifiers al =
  List.filter (fun a -> List.mem (get_name a) qualifier_attributes) al

let split_array_attributes al =
  List.partition (fun a -> List.mem (get_name a) qualifier_attributes) al

let split_storage_modifiers al =
  let isstoragemod ((an, _) : attribute) : bool =
    try
      match Hashtbl.find known_table an with
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
