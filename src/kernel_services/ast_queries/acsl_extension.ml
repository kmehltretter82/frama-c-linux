(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2019                                               *)
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

open Cil_types
open Logic_typing
open Logic_ptree

type extension_info = {
  ext_status: bool ;
  ext_preprocess: extension_preprocessing ;
  ext_typing: extension_typing ;
  ext_visit: extension_visit ;
  ext_printing: extension_printing ;
}
and extension_preprocessing =
  lexpr list -> lexpr list
and extension_typing =
  typing_context -> location -> lexpr list -> acsl_extension_kind
and extension_visit =
  Cil.cilVisitor -> acsl_extension_kind -> acsl_extension_kind Cil.visitAction
and extension_printing =
  Printer_api.extensible_printer_type -> Format.formatter ->
  acsl_extension_kind -> unit

(* Default extension *)

let default_preprocessing = Extlib.id

let default_typing typing_context loc l =
  let _ = loc in
  let typing = typing_context.type_predicate typing_context (Lenv.empty ()) in
  Ext_preds (List.map typing l)

let default_visit _ _ = Cil.DoChildren

let default_printing printer fmt = function
  | Ext_id i -> Format.fprintf fmt "%d" i
  | Ext_terms ts -> Pretty_utils.pp_list ~sep:",@ " printer#term fmt ts
  | Ext_preds ps -> Pretty_utils.pp_list ~sep:",@ " printer#predicate fmt ps

let default = {
  ext_status = false ;
  ext_preprocess = default_preprocessing ;
  ext_typing = default_typing ;
  ext_printing = default_printing ;
  ext_visit = default_visit ;
}

module Extensions = struct
  let ext_tbl = Hashtbl.create 5

  let find name =
    try snd (Hashtbl.find ext_tbl name)
    with Not_found ->
      Kernel.fatal ~current:true "unsupported clause of name '%s'" name

  let category name =
    Extlib.opt_map fst (Hashtbl.find_opt ext_tbl name)

  let is_extension = Hashtbl.mem ext_tbl

  let register category name info =
    if is_extension name then
      Kernel.warning ~wkey:Kernel.wkey_acsl_extension
        "Trying to register ACSL extension %s twice. Ignoring second extension"
        name
    else Hashtbl.add ext_tbl name (category, info)

  let preprocess name = (find name).ext_preprocess

  let typing name typing_context loc es =
    let ext_info = find name in
    let status = ext_info.ext_status in
    let typer =  ext_info.ext_typing in
    status, (typer typing_context loc es)

  let print name = (find name).ext_printing
  let visit name = (find name).ext_visit
end

(* Registration *)

let register_behavior =
  Extensions.register Ext_contract
let register_global =
  Extensions.register Ext_global
let register_code_annot =
  Extensions.register (Ext_code_annot Ext_here)
let register_code_annot_next_stmt =
  Extensions.register (Ext_code_annot Ext_next_stmt)
let register_code_annot_next_loop =
  Extensions.register (Ext_code_annot Ext_next_loop)
let register_code_annot_next_both =
  Extensions.register (Ext_code_annot Ext_next_both)

(* Setup global references *)

let () =
  Logic_env.set_extension_handler
    ~category:Extensions.category
    ~is_extension: Extensions.is_extension
    ~preprocess: Extensions.preprocess ;
  Logic_typing.set_extension_handler
    ~is_extension: Extensions.is_extension
    ~typer: Extensions.typing ;
  Cil.set_extension_handler
    ~visit: Extensions.visit ;
  Cil_printer.set_extension_handler
    ~print: Extensions.print

(* For Deprecation: *)

let deprecated_replace name ext = Hashtbl.add Extensions.ext_tbl name ext

let strong_cat = Hashtbl.create 5

let deprecated_find ?(strong=true) name cat op_name =
  match Hashtbl.find_opt Extensions.ext_tbl name with
  | None ->
    if strong then Hashtbl.add strong_cat name cat ;
    (cat, default)
  | Some (found_cat, ext) ->
    if strong && Hashtbl.mem strong_cat name then begin
      if found_cat = cat then (cat, ext)
      else
        Kernel.fatal
          "Registring %s for %s: this extension already exists for another \
           category"
          op_name name
    end else if strong then begin
      Hashtbl.add strong_cat name cat ;
      (cat, ext)
    end else
      (found_cat, ext)

let deprecated_register_typing name cat ext_status ext_typing =
  let cat, ext = deprecated_find name cat "typing" in
  let ext = { ext with ext_status ; ext_typing } in
  deprecated_replace name (cat, ext)

let deprecated_register_printing name cat ext_printing =
  let cat, ext = deprecated_find ~strong:false name cat "printing" in
  let ext = { ext with ext_printing } in
  deprecated_replace name (cat, ext)

let deprecated_register_visit name cat ext_visit =
  let cat, ext = deprecated_find name cat "visit" in
  let ext = { ext with ext_visit } in
  deprecated_replace name (cat, ext)

let () =
  Logic_typing.set_deprecated_extension_handler deprecated_register_typing ;
  Cil.set_deprecated_extension_handler deprecated_register_visit ;
  Cil_printer.set_deprecated_extension_handler deprecated_register_printing
