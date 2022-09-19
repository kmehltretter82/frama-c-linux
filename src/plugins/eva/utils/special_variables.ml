(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2022                                               *)
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

(* ----- Creation of varinfos and bases ------------------------------------- *)

let stdlib_attribute = Attr ("fc_stdlib_generated", [])

let register_new_var v typ =
  if Cil.isFunctionType typ
  then Globals.Functions.replace_by_declaration (Cil.empty_funspec()) v v.vdecl
  else Globals.Vars.add_decl v

let register_base vi validity alloc =
  match alloc with
  | None -> Base.register_memory_var vi validity
  | Some dealloc -> Base.register_allocated_var vi dealloc validity

let create_varinfo name ?descr ?(libc=false) typ =
  let vi = Cil.makeGlobalVar ~source:false ~temp:false name typ in
  if libc then vi.vattr <- Cil.addAttribute stdlib_attribute vi.vattr;
  if Option.is_some descr then vi.vdescr <- descr;
  register_new_var vi typ;
  vi

let create name ?descr ?libc typ validity alloc =
  let vi = create_varinfo name ?descr ?libc typ in
  let base = register_base vi validity alloc in
  vi, base

(* ----- Varinfos for function returning results ---------------------------- *)

module Retres =
  Kernel_function.Make_Table
    (Cil_datatype.Varinfo)
    (struct
      let name = "Eva.Eva_variables.Retres"
      let size = 9
      let dependencies = [ Ast.self; Self.state ]
    end)
let () = Ast.add_monotonic_state Retres.self

let check_size typ kf =
  try ignore (Cil.bitsSizeOf typ)
  with Cil.SizeOfError _ ->
    Self.abort ~current:true
      "function %a returns a value of unknown size. Aborting"
      Kernel_function.pretty kf

let create_retres_variable typ kf =
  let () = check_size typ kf in
  let name = Format.asprintf "\\result<%a>" Kernel_function.pretty kf in
  Cil.makeVarinfo ~source:true ~temp:false false false name typ

let get_retres kf =
  let vi = Kernel_function.get_vi kf in
  let typ = Cil.getReturnType vi.vtype in
  if Cil.isVoidType typ
  then None
  else Some (Retres.memo (create_retres_variable typ) kf)

(* ----- Other created variables -------------------------------------------- *)

module CreatedVars =
  State_builder.Hashtbl
    (Datatype.String.Hashtbl)
    (Cil_datatype.Varinfo)
    (struct
      let name = "Eva.Eva_variables.CreatedVars"
      let dependencies = [Ast.self; Self.state]
      let size = 32
    end)


(* Is [t2] an array of elements of type [t1] or, if [t1] is an array type,
   the same array type with no length? *)
let is_array_extended t1 t2 =
  match Cil.unrollType t1, Cil.unrollType t2 with
  | (TArray (t1, Some _, _) | t1), TArray (t2, None, []) ->
    Cil_datatype.Typ.equal t1 t2
  | _ -> false

(* If [vi] and [v2] are two variable base validity, is the validity [v1]
   included in [v2]? *)
let is_validity_included v1 v2 =
  match v1, v2 with
  | Base.Variable v1, Base.Variable v2 ->
    Integer.le v2.min_alloc v1.min_alloc
    && Integer.ge v2.max_alloc v1.max_alloc
    && (not v1.weak || v2.weak)
  | _ -> false

(* Checks that the previously created variable [vi] with base [base] is
   compatible with the expected [typ] and [validity]. The variable should
   have exactly these type and validity, except for dynamic allocation bases:
   these bases can be extended during an analysis to represent more
   allocations, so the existing variable may have "larger" type and validity
   than requested. *)
let check_existing_variable name vi base typ validity alloc =
  let base_validity = Base.validity base in
  if not (Cil_datatype.Typ.equal typ vi.vtype
          || (alloc <> None && is_array_extended typ vi.vtype))
  || not (Base.Validity.equal validity base_validity
          || (alloc <> None && is_validity_included validity base_validity))
  then
    Self.fatal
      "Trying to register a new variable %s with type %a and validity %a, \
       incompatible with the existing variable %a of type %a and validity %a."
      name Printer.pp_typ typ Base.pretty_validity validity
      Printer.pp_varinfo vi Printer.pp_typ vi.vtype
      Base.pretty_validity base_validity

let register name ?descr ?libc typ validity alloc =
  match CreatedVars.find name with
  | vi ->
    let base = Base.of_varinfo vi in
    check_existing_variable name vi base typ validity alloc;
    vi, base
  | exception Not_found ->
    let vi, base = create name ?descr ?libc typ validity alloc in
    CreatedVars.replace name vi;
    vi, base

let create_global name ?descr ?libc ?validity typ =
  let validity =
    match validity with
    | None -> Base.validity_from_type typ
    | Some validity -> validity
  in
  register name ?descr ?libc typ validity None

let create_allocated name typ ~weak ~min_alloc ~max_alloc ~kind =
  (* Note that min_alloc may be negative (-1) if the allocated size is 0 *)
  assert Integer.(ge min_alloc minus_one);
  assert Integer.(ge max_alloc min_alloc);
  let variable_v =
    Base.create_variable_validity ~weak ~min_alloc ~max_alloc
  in
  let validity = Base.Variable variable_v in
  register name typ validity (Some kind)

(* ----- Import created variables from another Frama-C project -------------- *)

let import_retres project =
  let gather () = Retres.fold (fun kf vi acc -> (kf, vi) :: acc) [] in
  let list = Project.on project gather () in
  let import (kf, vi) =
    match Ast_diff.Kernel_function.find kf with
    | `Same new_kf ->
      let new_vi = create_retres_variable vi.vtype new_kf in
      Retres.add new_kf new_vi;
      Ast_diff.Varinfo.add vi (`Same new_vi)
    |  `Partial _ | `Not_present | exception Not_found -> ()
  in
  List.iter import list

let import_created project =
  let get_info name vi =
    let base = Base.of_varinfo vi in
    let validity = Base.validity base in
    let deallocation =
      match base with
      | Allocated (_, deallocation, _) -> Some deallocation
      | _ -> None
    in
    (name, vi, validity, deallocation)
  in
  let gather () =
    CreatedVars.fold (fun name vi acc -> get_info name vi :: acc) []
  in
  let list = Project.on project gather () in
  let import (name, vi, validity, alloc) =
    let new_vi, _base = register name vi.vtype validity alloc in
    Ast_diff.Varinfo.add vi (`Same new_vi)
  in
  List.iter import list

let import project =
  assert (Project.equal project (Ast_diff.Orig_project.get ()));
  import_retres project;
  import_created project
