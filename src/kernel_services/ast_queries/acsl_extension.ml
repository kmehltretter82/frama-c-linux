(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2020                                               *)
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

type extension_preprocessor =
  lexpr list -> lexpr list
type extension_typer =
  typing_context -> location -> lexpr list -> acsl_extension_kind
type extension_preprocessor_block =
  string * extended_decl list -> string * extended_decl list
type extension_typer_block =
  typing_context -> location -> string * extended_decl list -> acsl_extension_kind
type extension_visitor =
  Cil.cilVisitor -> acsl_extension_kind -> acsl_extension_kind Cil.visitAction
type extension_printer =
  Printer_api.extensible_printer_type -> Format.formatter ->
  acsl_extension_kind -> unit
type extension_standard = {
  preprocessor: extension_preprocessor ;
  typer: extension_typer ;
  status: bool ;
}
type extension_commun = {
  category: ext_category ;
  visitor: extension_visitor ;
  printer: extension_printer ;
  short_printer: extension_printer ;
}
type extension_block = {
  preprocessor: extension_preprocessor_block ;
  typer: extension_typer_block ;
  status: bool ;
}
type extension = {
  preprocessor: extension_preprocessor ;
  typer: extension_typer ;
  status: bool ;
  category: ext_category ;
  visitor: extension_visitor ;
  printer: extension_printer ;
  short_printer: extension_printer ;
}

let default_printer printer fmt = function
  | Ext_id i -> Format.fprintf fmt "%d" i
  | Ext_terms ts -> Pretty_utils.pp_list ~sep:",@ " printer#term fmt ts
  | Ext_preds ps -> Pretty_utils.pp_list ~sep:",@ " printer#predicate fmt ps
  | Ext_annot (_,an) -> Pretty_utils.pp_list ~pre:"@[<v 0>" ~suf:"@]@\n" ~sep:"@\n"
                          printer#extended fmt an

let default_short_printer name printer fmt = function
  | Ext_id _ | Ext_terms _ | Ext_preds _ -> Format.fprintf fmt "%s" name
  | Ext_annot (id,an) ->
    Format.fprintf fmt "%s@ {@\n%a@]@\n}" id (Pretty_utils.pp_list ~sep:"@\n" printer#extended) an

let make
    name category
    ?(preprocessor=Extlib.id)
    typer
    ?(visitor=fun _ _ -> Cil.DoChildren)
    ?(printer=default_printer)
    ?(short_printer=default_short_printer name)
    status : extension_standard*extension_commun =
  { preprocessor; typer; status},{ category; visitor; printer; short_printer }

let make_block
    name category
    ?(preprocessor=Extlib.id)
    typer
    ?(visitor=fun _ _ -> Cil.DoChildren)
    ?(printer=default_printer)
    ?(short_printer=default_short_printer name)
    status : extension_block*extension_commun =
  { preprocessor; typer; status},{ category; visitor; printer; short_printer }

module Extensions = struct
  (*hash table for  category, visitor, printer and short_priner of extensions*)
  let ext_tbl = Hashtbl.create 5

  (*hash table for status, preprocessor and typer of standard extensions*)
  let ext_sta_tbl = Hashtbl.create 5

  (*hash table for status, preprocessor and visitor of block extensions*)
  let ext_block_tbl = Hashtbl.create 5

  let find_standard name :extension_standard =
    try Hashtbl.find ext_sta_tbl name with Not_found ->
      Kernel.fatal ~current:true "unsupported clause of name '%s'" name

  let find_commun name :extension_commun =
    try Hashtbl.find ext_tbl name with Not_found ->
      Kernel.fatal ~current:true "unsupported clause of name '%s'" name

  let find_block name :extension_block =
    try Hashtbl.find ext_block_tbl name with Not_found ->
      Kernel.fatal ~current:true "unsupported clause of name '%s'" name

  (* [Logic_lexer] can ask for something that is not a category, which is not
     a fatal error. *)
  let category name = (Hashtbl.find ext_tbl name).category

  let is_extension = Hashtbl.mem ext_tbl

  let is_extension_block = Hashtbl.mem ext_block_tbl

  let register
      cat name ?preprocessor typer ?visitor ?printer ?short_printer status =
    let info1,info2 =
      make name cat ?preprocessor typer ?visitor ?printer ?short_printer status
    in
    if is_extension name then
      Kernel.warning ~wkey:Kernel.wkey_acsl_extension
        "Trying to register ACSL extension %s twice. Ignoring second extension"
        name
    else
      begin
        Hashtbl.add ext_sta_tbl name info1;
        Hashtbl.add ext_tbl name info2
      end

  let register_block
      cat name ?preprocessor typer ?visitor ?printer ?short_printer status =
    let info1,info2 =
      make_block name cat ?preprocessor typer ?visitor ?printer ?short_printer status
    in
    if is_extension name then
      Kernel.warning ~wkey:Kernel.wkey_acsl_extension
        "Trying to register ACSL extension %s twice. Ignoring second extension"
        name
    else
      begin
        Hashtbl.add ext_block_tbl name info1;
        Hashtbl.add ext_tbl name info2
      end

  let preprocess name = (find_standard name).preprocessor

  let preprocess_block name = (find_block name).preprocessor

  let typing name typing_context loc es =
    let ext_info = find_standard name in
    let status = ext_info.status in
    let typer =  ext_info.typer in
    let normal_error = ref false in
    let has_error () = normal_error := true in
    let wrapper =
      typing_context.on_error (typer typing_context loc) has_error
    in
    try status, wrapper es
    with
    | (Log.AbortError _ | Log.AbortFatal _) as exn -> raise exn
    | exn when not !normal_error ->
      Kernel.fatal "Typechecking ACSL extension %s raised exception %s"
        name (Printexc.to_string exn)

  let typing_block name typing_context loc es =
    let ext_info = find_block name in
    let status = ext_info.status in
    let typer =  ext_info.typer in
    let normal_error = ref false in
    let has_error () = normal_error := true in
    let wrapper =
      typing_context.on_error (typer typing_context loc) has_error
    in
    try status, wrapper es
    with
    | (Log.AbortError _ | Log.AbortFatal _) as exn -> raise exn
    | exn when not !normal_error ->
      Kernel.fatal "Typechecking ACSL extension %s raised exception %s"
        name (Printexc.to_string exn)

  let visit name = (find_commun name).visitor

  let print name printer fmt kind =
    let pp = (find_commun name).printer printer in
    match kind with
    | Ext_annot (id,_) ->
      Format.fprintf fmt "@[<v 2>@[%s %s {@]@\n%a}@]" name id pp kind
    | _ ->
      Format.fprintf fmt "@[<hov 2>%s %a;@]" name pp kind

  let short_print name printer fmt kind =
    let pp = (find_commun name).short_printer in
    Format.fprintf fmt "%a" (pp printer) kind
end

(* Registration functions *)

let register_behavior =
  Extensions.register Ext_contract
let register_global =
  Extensions.register Ext_global
let register_global_block =
  Extensions.register_block Ext_global
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
    ~preprocess: Extensions.preprocess
    ~is_extension_block: Extensions.is_extension_block
    ~preprocess_block: Extensions.preprocess_block;
  Logic_typing.set_extension_handler
    ~is_extension: Extensions.is_extension
    ~typer: Extensions.typing
    ~typer_block: Extensions.typing_block ;
  Cil.set_extension_handler
    ~visit: Extensions.visit ;
  Cil_printer.set_extension_handler
    ~print: Extensions.print
    ~short_print:Extensions.short_print

(* For Deprecation: *)

let deprecated_replace name ext =
  let info1:extension_standard = {
    preprocessor = ext.preprocessor ;
    typer = ext.typer ;
    status = ext.status ;
  }
  in
  let info2:extension_commun  = {
    category = ext.category ;
    visitor = ext.visitor ;
    printer = ext.printer ;
    short_printer = ext.printer ;
  }
  in
  Hashtbl.add Extensions.ext_sta_tbl name info1;
  Hashtbl.add Extensions.ext_tbl name info2

let strong_cat = Hashtbl.create 5

let default_typer _typing_context _loc _l = assert false

let merge ((info1:extension_standard),(info2:extension_commun)) :extension =
  {preprocessor = info1.preprocessor ;
   typer = info1.typer ;
   status = info1.status ;
   category = info2.category ;
   visitor = info2.visitor ;
   printer = info2.printer ;
   short_printer = info2.printer}

let deprecated_find ?(strong=true) name cat op_name =
  match Hashtbl.find_opt Extensions.ext_sta_tbl name with
  | None ->
    if strong then Hashtbl.add strong_cat name cat ;
    merge (make name cat default_typer false)
  | Some ext1 ->
    let ext2 = Extensions.find_commun name in
    if strong && Hashtbl.mem strong_cat name then begin
      if ext2.category = cat then merge (ext1,ext2)
      else
        Kernel.fatal
          "Registring %s for %s: this extension already exists for another \
           category"
          op_name name
    end else if strong then begin
      Hashtbl.add strong_cat name cat ;
      let ext2 = { ext2 with category = cat } in
      merge (ext1,ext2)
    end else merge (ext1,ext2)

let deprecated_register_typing name cat status typer =
  deprecated_replace name
    { (deprecated_find name cat "typing") with status ; typer }

let deprecated_register_printing name cat printer =
  deprecated_replace name
    { (deprecated_find ~strong:false name cat "printing") with printer }

let deprecated_register_visit name cat visitor =
  deprecated_replace name
    { (deprecated_find name cat "visit") with visitor }

let () =
  Logic_typing.set_deprecated_extension_handler deprecated_register_typing ;
  Cil.set_deprecated_extension_handler deprecated_register_visit ;
  Cil_printer.set_deprecated_extension_handler deprecated_register_printing
