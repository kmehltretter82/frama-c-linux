(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2020                                               *)
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
open Cil_datatype

let rtl_files () =
  List.map
    (fun d -> Options.Share.get_file ~mode:`Must_exist d)
    [ "e_acsl_gmp_api.h";
      "e_acsl.h" ]

(* create the RTL AST in a fresh project *)
let create_rtl_ast prj =
  Project.on
    prj
    (fun () ->
       (* compute the RTL AST in the standard E-ACSL setting *)
       if Plugin.is_present "variadic" then
         Dynamic.Parameter.Bool.off "-variadic-translation" ();
       Kernel.Keep_unused_specified_functions.off ();
       Kernel.CppExtraArgs.add
         (Format.asprintf " -DE_ACSL_MACHDEP=%s" (Kernel.Machdep.get ()));
       Kernel.Files.set (rtl_files ());
       Ast.get ())
    ()

(* Note: vids, sids and eids are shared between projects (see implementation of
   [Cil_const]). Therefore, no need to set them when inserting the corresponding
   global into the AST. *)

(* Tables that contain RTL's symbols. Useful to know whether some symbols is
    part of the RTL. *)
module Symbols: sig
  val add_global: global -> unit
  val mem_global: global -> bool
  val add_kf: kernel_function -> unit
  val mem_kf: kernel_function -> bool
  val add_vi: string -> varinfo -> unit
  val mem_vi: string -> bool
  exception Unregistered of string
  val find_vi: string -> varinfo (* may raise Unregistered *)
  (*  val debug: unit -> unit*)
end = struct

  let globals: unit Global.Hashtbl.t = Global.Hashtbl.create 17
  let kfs: unit Kernel_function.Hashtbl.t = Kernel_function.Hashtbl.create 17
  let vars
    : varinfo Datatype.String.Hashtbl.t
    = Datatype.String.Hashtbl.create 17

  let add_global g = Global.Hashtbl.add globals g ()
  let mem_global g = Global.Hashtbl.mem globals g

  let add_kf g = Kernel_function.Hashtbl.add kfs g ()
  let mem_kf g = Kernel_function.Hashtbl.mem kfs g

  let add_vi s vi = Datatype.String.Hashtbl.add vars s vi
  let mem_vi s = Datatype.String.Hashtbl.mem vars s
  exception Unregistered of string
  let find_vi s =
    try Datatype.String.Hashtbl.find vars s
    with Not_found -> raise (Unregistered s)

(*
  let debug () =
    Global.Hashtbl.iter
      (fun g1 () -> Format.printf "RTL %a@." Printer.pp_global g1)
      rtl;
    Varinfo.Hashtbl.iter
      (fun g1 g2 -> Format.printf "VAR %a -> %a@."
          Printer.pp_varinfo g1
          Printer.pp_varinfo g2)
      vars;
    Typ.Hashtbl.iter
      (fun g1 g2 -> Format.printf "TYP %a -> %a@."
          Printer.pp_typ g1
          Printer.pp_typ g2)
      types;
    Global_annotation.Hashtbl.iter
      (fun g1 g2 -> Format.printf "ANNOT %a -> %a@."
          Printer.pp_global_annotation g1
          Printer.pp_global_annotation g2)
      annots
*)
end

(* NOTE: do not use [Mergecil.merge] since all [ast]'s symbols must be kept
   unchanged: so do it ourselves. Thanksfully, we merge in a particular
   setting because we know what the RTL is. Therefore merging is far from being
   as complicated as [Mergecil]. *)

(* lookup globals from [rtl_ast] in the current [ast] and fill the [Symbols]'
   tables.
   @return the list of globals to be inserted into [ast], in reverse order. *)
let lookup_rtl_globals rtl_ast =
  (* [do_it ~add mem acc l g] checks whether the global does exist in the user's
     AST. If not, add it to the corresponding symbol table(s). *)
  let rec do_it ?(add=fun _g -> ()) mem acc l g =
    if mem g then do_globals (g :: acc) l
    else begin
      add g;
      Symbols.add_global g;
      do_globals (g :: acc) l
    end
  (* [do_ty] is [do_it] for types *)
  and do_ty acc l g kind tname =
    let mem _g =
      try
        ignore (Globals.Types.find_type kind tname);
        true
      with Not_found ->
        false
    in
    do_it mem acc l g
  and do_globals acc globs =
    match globs with
    | [] ->
      acc
    | GType(ti, _loc) as g :: l ->
      do_ty acc l g Logic_typing.Typedef ti.tname
    | GCompTag(ci, _loc) | GCompTagDecl(ci, _loc) as g :: l ->
      let k = if ci.cstruct then Logic_typing.Struct else Logic_typing.Union in
      do_ty acc l g k ci.cname
    | GEnumTag(ei, _loc) | GEnumTagDecl(ei, _loc) as g :: l  ->
      do_ty acc l g Logic_typing.Enum ei.ename
    | GVarDecl(vi, (pos, _)) | GVar(vi, _, (pos, _)) as g :: l  ->
      let tunit = Translation_unit pos.Filepath.pos_path in
      let mem _g =
        match Globals.Syntactic_search.find_in_scope vi.vorig_name tunit with
        | None -> false
        | Some _ -> true
      in
      let add g =
        Symbols.add_vi vi.vname vi;
        match g with
        | GVarDecl _ -> Globals.Vars.add_decl vi
        | GVar(_, ii, _) -> Globals.Vars.add vi ii
        | _ -> assert false
      in
      do_it ~add mem acc l g
    | GFunDecl(_, vi, _loc) | GFun({ svar = vi }, _loc) as g :: l ->
      let mem _g =
        try ignore (Globals.Functions.find_by_name vi.vname); true
        with Not_found -> false
      in
      let add _g =
        Symbols.add_vi vi.vname vi;
        (* functions will be registered in kernel's table after substitution of
           RTL's symbols inside them *)
      in
      do_it ~add mem acc l g
    | GAnnot _ :: l ->
      (* ignoring annotations from the AST *)
      do_globals acc l
    | GAsm _ | GPragma _ | GText _ as g :: _l  ->
      Kernel.fatal "unexpected global %a" Printer.pp_global g
  in
  do_globals [] rtl_ast.globals

(* [substitute_rtl_symbols] registers the correct symbols for RTL's functions *)
let substitute_rtl_symbols rtl_prj = function
  | GVarDecl _ | GVar _ as g ->
    g
  | GFunDecl(_, vi, loc) | GFun({ svar = vi }, loc) as g ->
    let get_kf vi =
      try
        Globals.Functions.get vi
      with Not_found ->
        Options.fatal "unknown function %s in project %a"
          vi.vname
          Project.pretty (Project.current ())
    in
    let selection =
      State_selection.of_list
        [ Globals.Functions.self; Annotations.funspec_state ]
    in
    (* get the RTL's formals and spec *)
    let formals, spec =
      Project.on
        rtl_prj
        ~selection
        (fun vi ->
           let kf = get_kf vi in
           Kernel_function.get_formals kf,
           Annotations.funspec ~populate:false kf)
        vi
    in
    (match g with
     | GFunDecl _ ->
       Globals.Functions.replace_by_declaration spec vi loc
     | GFun(fundec, _) ->
       Globals.Functions.replace_by_definition spec fundec loc
     | _ -> assert false);
    (* [Globals.Functions.replace_by_declaration] assigns new vids to formals:
       get them back to their original ids in order to have the correct ids in
       [spec] *)
    let kf = get_kf vi in
    List.iter2
      (fun rtl_vi src_vi -> src_vi.vid <- rtl_vi.vid)
      formals
      (Kernel_function.get_formals kf);
    Cil.unsafeSetFormalsDecl vi formals;
    Annotations.register_funspec ~emitter:Options.emitter kf;
    Symbols.add_kf kf;
    g
  | GType _ | GCompTag _ | GCompTagDecl _ | GEnumTag _ | GEnumTagDecl _
  | GAnnot _ | GAsm _ | GPragma _ | GText _ ->
    assert false

(* [insert_rtl_globals] adds the rtl symbols into the user's AST *)
let insert_rtl_globals rtl_prj rtl_globals ast =
  let add_ty acc old_g new_g =
    let g = if Symbols.mem_global old_g then old_g else new_g in
    (* keep them in the AST even if already in the user's one to prevent forward
       references *)
    g :: acc
  in
  let rec add acc = function
    | [] ->
      acc
    | GType _ | GCompTagDecl _ | GEnumTagDecl _ as g :: l ->
      (* RTL types contain no libc values: no need to substitute inside them *)
      let acc = add_ty acc g g in
      add acc l
    | GCompTag(ci, loc) as g :: l ->
      (* RTL's structure definitions that are already defined in the AST shall
         be only declared *)
      let acc = add_ty acc g (GCompTagDecl(ci, loc)) in
      add acc l
    | GEnumTag(ei, loc) as g :: l ->
      (* RTL's enum definitions that are already defined in the AST shall be
         only declared *)
      let acc = add_ty acc g (GEnumTagDecl(ei, loc)) in
      add acc l
    | GVarDecl _ | GVar _ | GFunDecl _ | GFun _ as g :: l ->
      let acc =
        if Symbols.mem_global g then
          let g = substitute_rtl_symbols rtl_prj g in
          g :: acc
        else
          acc
      in
      add acc l
    | GAnnot _ | GAsm _ | GPragma _ | GText _ as g :: _l  ->
      Kernel.fatal "unexpected global %a" Printer.pp_global g
  in
  ast.globals <- add ast.globals rtl_globals

let link rtl_prj =
  Options.feedback ~level:2 "link the E-ACSL RTL with the user source code";
  let rtl_ast = create_rtl_ast rtl_prj in
  let ast = Ast.get () in
  let rtl_globals = lookup_rtl_globals rtl_ast in
  (*  Symbols.debug ();*)
  insert_rtl_globals rtl_prj rtl_globals ast;
  Ast.mark_as_grown ()

(*
Local Variables:
compile-command: "make -C ../../../../.."
End:
*)
