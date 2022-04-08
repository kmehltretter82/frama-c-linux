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

let register name ?descr ?libc typ validity alloc =
  match CreatedVars.find name with
  | vi ->
    let base = Base.of_varinfo vi in
    assert (Cil_datatype.Typ.equal typ vi.vtype);
    assert (Base.Validity.equal validity (Base.validity base));
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
