(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2024                                               *)
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
type extension_same =
  acsl_extension_kind -> acsl_extension_kind -> Ast_diff.is_same_env -> bool

type register_extension =
  plugin:string -> string ->
  ?preprocessor:extension_preprocessor -> extension_typer ->
  ?visitor:extension_visitor ->
  ?printer:extension_printer -> ?short_printer:extension_printer ->
  ?is_same_ext:extension_same -> bool ->
  unit

type register_extension_block =
  plugin: string -> string ->
  ?preprocessor:extension_preprocessor_block -> extension_typer_block ->
  ?visitor:extension_visitor ->
  ?printer:extension_printer -> ?short_printer:extension_printer ->
  ?is_same_ext:extension_same -> bool -> unit

type extension_single = {
  preprocessor: extension_preprocessor ;
  typer: extension_typer ;
  status: bool ;
}
type extension_block = {
  preprocessor: extension_preprocessor_block ;
  typer: extension_typer_block ;
  status: bool ;
}
type extension_common = {
  category: ext_category ;
  visitor: extension_visitor ;
  printer: extension_printer ;
  short_printer: extension_printer ;
  plugin: string;
  is_same_ext: extension_same;
}

let default_printer printer fmt = function
  | Ext_id i -> Format.fprintf fmt "%d" i
  | Ext_terms ts -> Pretty_utils.pp_list ~sep:",@ " printer#term fmt ts
  | Ext_preds ps -> Pretty_utils.pp_list ~sep:",@ " printer#predicate fmt ps
  | Ext_annot (_,an) -> Pretty_utils.pp_list ~pre:"@[<v 0>" ~suf:"@]@\n" ~sep:"@\n"
                          printer#extended fmt an

let default_short_printer name _printer fmt _ext_kind = Format.fprintf fmt "%s" name

let rec default_is_same_ext ext1 ext2 env =
  match ext1, ext2 with
  | Ext_id n1, Ext_id n2 -> n1 = n2
  | Ext_terms l1, Ext_terms l2 ->
    Ast_diff.is_same_list Ast_diff.is_same_term l1 l2 env
  | Ext_preds l1, Ext_preds l2 ->
    Ast_diff.is_same_list Ast_diff.is_same_predicate l1 l2 env
  | Ext_annot(s1,l1), Ext_annot(s2,l2) ->
    s1 = s2 && Ast_diff.is_same_list default_is_same_ext_kind l1 l2 env
  | (Ext_id _ | Ext_terms _ | Ext_preds _ | Ext_annot _), _ -> false
and default_is_same_ext_kind ext1 ext2 env =
  default_is_same_ext ext1.ext_kind ext2.ext_kind env

let make
    ~plugin
    name category
    ?(preprocessor=Fun.id)
    typer
    ?(visitor=fun _ _ -> Cil.DoChildren)
    ?(printer=default_printer)
    ?(short_printer=default_short_printer name)
    ?(is_same_ext=default_is_same_ext)
    status : extension_single*extension_common =
  { preprocessor; typer; status},
  { category; visitor; printer; short_printer; plugin; is_same_ext }

let make_block
    ~plugin
    name category
    ?(preprocessor=Fun.id)
    typer
    ?(visitor=fun _ _ -> Cil.DoChildren)
    ?(printer=default_printer)
    ?(short_printer=default_short_printer name)
    ?(is_same_ext=default_is_same_ext)
    status : extension_block*extension_common =
  { preprocessor; typer; status},
  { category; visitor; printer; short_printer; plugin; is_same_ext }

module Extensions = struct
  (*hash table for  category, visitor, printer and short_printer of extensions*)
  let ext_tbl = Hashtbl.create 5

  (*hash table for status, preprocessor and typer of single extensions*)
  let ext_single_tbl = Hashtbl.create 5

  (*hash table for status, preprocessor and typer of block extensions*)
  let ext_block_tbl = Hashtbl.create 5

  let find_single name :extension_single =
    try Hashtbl.find ext_single_tbl name with Not_found ->
      Kernel.fatal ~current:true "unsupported clause of name '%s'" name

  let find_common name :extension_common =
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

  let register cat ~plugin name
      ?preprocessor typer ?visitor ?printer ?short_printer ?is_same_ext status =
    let info1,info2 =
      make ~plugin name cat ?preprocessor typer
        ?visitor ?printer ?short_printer ?is_same_ext status
    in
    if is_extension name then
      Kernel.warning ~wkey:Kernel.wkey_acsl_extension
        "Trying to register ACSL extension %s twice. Ignoring second extension"
        name
    else
      begin
        Hashtbl.add ext_single_tbl name info1;
        Hashtbl.add ext_tbl name info2
      end

  let register_block cat ~plugin name
      ?preprocessor typer ?visitor ?printer ?short_printer ?is_same_ext status =
    let info1,info2 =
      make_block ~plugin name cat ?preprocessor typer
        ?visitor ?printer ?short_printer ?is_same_ext status
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

  let preprocess name = (find_single name).preprocessor

  let preprocess_block name = (find_block name).preprocessor

  let typing name typing_context loc es =
    let ext_info = find_single name in
    let status = ext_info.status in
    let typer =  ext_info.typer in
    let normal_error = ref false in
    let has_error _ = normal_error := true in
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
    let has_error _ = normal_error := true in
    let wrapper =
      typing_context.on_error (typer typing_context loc) has_error
    in
    try status, wrapper es
    with
    | (Log.AbortError _ | Log.AbortFatal _) as exn -> raise exn
    | exn when not !normal_error ->
      Kernel.fatal "Typechecking ACSL extension %s raised exception %s"
        name (Printexc.to_string exn)

  let visit name = (find_common name).visitor

  let print name printer fmt kind =
    let ext_common = find_common name in
    let plugin = ext_common.plugin in
    let full_name =
      if Datatype.String.equal plugin "kernel"
      then name
      else Format.sprintf "\\%s::%s" plugin name
    in
    let pp = ext_common.printer printer in
    match kind with
    | Ext_annot (id,_) ->
      Format.fprintf fmt "@[<v 2>@[%s %s {@]@\n%a}@]" full_name id pp kind
    | _ ->
      Format.fprintf fmt "@[<hov 2>%s %a;@]" full_name pp kind

  let short_print name printer fmt kind =
    let pp = (find_common name).short_printer in
    Format.fprintf fmt "%a" (pp printer) kind

  let is_same_ext name ext1 ext2 =
    let is_same = (find_common name).is_same_ext in
    is_same ext1 ext2

  let extension_from name = (find_common name).plugin
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
    ~preprocess_block: Extensions.preprocess_block
    ~extension_from:Extensions.extension_from;
  Logic_typing.set_extension_handler
    ~is_extension: Extensions.is_extension
    ~typer: Extensions.typing
    ~typer_block: Extensions.typing_block ;
  Cil.set_extension_handler
    ~visit: Extensions.visit ;
  Cil_printer.set_extension_handler
    ~print: Extensions.print
    ~short_print:Extensions.short_print;
  Ast_diff.set_extension_diff
    ~is_same_ext: Extensions.is_same_ext
