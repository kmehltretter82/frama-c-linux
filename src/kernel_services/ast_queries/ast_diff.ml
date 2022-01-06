(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2021                                               *)
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

module Orig_project =
  State_builder.Option_ref(Project.Datatype)(
  struct
    let name = "Ast_diff.OrigProject"
    let dependencies = []
  end)

type 'a correspondance =
  [ `Same of 'a (** symbol with identical definition has been found. *)
  | `Not_present (** no correspondance *)
  ]

module Correspondance =
  Datatype.Polymorphic(
  struct
    type 'a t = 'a correspondance
    let name a = Type.name a ^ " correspondance"
    let module_name = "Correspondance"
    let structural_descr _ = Structural_descr.t_abstract
    let reprs x = [ `Not_present; `Same x]
    let mk_equal eq x y =
      match x,y with
      | `Same x, `Same y -> eq x y
      | `Not_present, `Not_present -> true
      | `Same _, `Not_present
      | `Not_present, `Same _ -> false
    let mk_compare cmp x y =
      match x,y with
      | `Not_present, `Not_present -> 0
      | `Not_present, `Same _ -> -1
      | `Same x, `Same y -> cmp x y
      | `Same _, `Not_present -> 1
    let mk_hash h = function
      | `Same x -> 117 * h x
      | `Not_present -> 43
    let map f = function
      | `Same x -> `Same (f x)
      | `Not_present -> `Not_present
    let mk_internal_pretty_code pp prec fmt = function
      | `Not_present -> Format.pp_print_string fmt "`Not_present"
      | `Same x ->
        let pp fmt = Format.fprintf fmt "`Same %a" (pp Type.Call) x in
        Type.par prec Call fmt pp
    let mk_pretty pp fmt = function
      | `Not_present -> Format.pp_print_string fmt "N/A"
      | `Same x -> Format.fprintf fmt " => %a" pp x
    let mk_varname v = function
      | `Not_present -> "x"
      | `Same x -> v x ^ "_c"
    let mk_mem_project mem query = function
      | `Not_present -> false
      | `Same x -> mem query x
  end
  )

type kf_correspondance =
  [ kernel_function correspondance
  | `Same_spec of kernel_function (** body has changed, but spec is identical *)
  | `Different_calls of kernel_function
  ]

module Kf_correspondance =
  Datatype.Make(
  struct
    let name = "Kf_correspondance"
    module C = Correspondance.Make(Kernel_function)
    include Datatype.Serializable_undefined
    type t = kf_correspondance
    let reprs =
      let kf = List.hd Kernel_function.reprs in
      `Same_spec kf :: (C.reprs :> t list)
    let compare x y =
      match x,y with
      | `Same_spec f1, `Same_spec f2 -> Kernel_function.compare f1 f2
      | `Same_spec _, _ -> 1
      | _, `Same_spec _ -> -1
      | `Different_calls f1, `Different_calls f2 -> Kernel_function.compare f1 f2
      | `Different_calls _, _ -> 1
      | _, `Different_calls _ -> -1
      | (#correspondance as x), (#correspondance as y) -> C.compare x y
    let equal = Datatype.from_compare
    let hash = function
      | `Same_spec f -> 57 * (Kernel_function.hash f)
      | `Different_calls f -> 79 * (Kernel_function.hash f)
      | #correspondance as x -> C.hash x
    let internal_pretty_code p fmt = function
      | `Same_spec f ->
        let pp fmt =
          Format.fprintf fmt "`Same_spec %a"
            (Kernel_function.internal_pretty_code Type.Call) f
        in
        Type.par p Call fmt pp
      | `Different_calls f ->
        let pp fmt =
          Format.fprintf fmt "`Different_calls %a"
            (Kernel_function.internal_pretty_code Type.Call) f
        in
        Type.par p Call fmt pp
      | #correspondance as x -> C.internal_pretty_code p fmt x
    let pretty fmt = function
      | `Same_spec f ->
        Format.fprintf fmt "-> (contract) %a" Kernel_function.pretty f
      | `Different_calls f ->
        Format.fprintf fmt " -> (callees differ) %a" Kernel_function.pretty f
      | #correspondance as x -> C.pretty fmt x
  end)

module Info(I: sig val name: string end) =
  (struct
    let name = "Ast_diff." ^ I.name
    let dependencies = [Ast.self; Orig_project.self ]
    let size = 43
  end)

module Build(D:Datatype.S_with_collections) =
  State_builder.Hashtbl(D.Hashtbl)(Correspondance.Make(D))
    (Info(struct let name = "Ast_diff." ^ D.name end))

module Varinfo = Build(Cil_datatype.Varinfo)

module Compinfo = Build(Cil_datatype.Compinfo)

module Enuminfo = Build(Cil_datatype.Enuminfo)

module Enumitem = Build(Cil_datatype.Enumitem)

module Typeinfo = Build(Cil_datatype.Typeinfo)

module Stmt = Build(Cil_datatype.Stmt)

module Logic_info = Build(Cil_datatype.Logic_info)

module Logic_type_info = Build(Cil_datatype.Logic_type_info)

module Fieldinfo = Build(Cil_datatype.Fieldinfo)

module Model_info = Build(Cil_datatype.Model_info)

module Logic_var = Build(Cil_datatype.Logic_var)

module Kernel_function =
  State_builder.Hashtbl(Kernel_function.Hashtbl)(Kf_correspondance)
    (Info(struct let name = "Ast_diff.Kernel_function" end))

module Fundec = Build(Cil_datatype.Fundec)

(** TODO: use location info to detect potential renaming.
    Requires some information about syntactic diff. *)
let find_candidate_type ?loc:_loc ti =
  if Globals.Types.mem_type Logic_typing.Typedef ti.tname then begin
    match Globals.Types.global Logic_typing.Typedef ti.tname with
    | GType(ti,_) -> Some ti
    | g ->
      Kernel.fatal
        "Expected typeinfo instead of %a" Cil_datatype.Global.pretty g
  end else None

let find_candidate_compinfo ?loc:_loc ci =
  let su = if ci.cstruct then Logic_typing.Struct else Logic_typing.Union in
  if Globals.Types.mem_type su ci.cname then begin
    match Globals.Types.global su ci.cname with
    | GCompTag (ci,_) | GCompTagDecl(ci,_) -> Some ci
    | g ->
      Kernel.fatal
        "Expected aggregate definition instead of %a"
        Cil_datatype.Global.pretty g
  end else None

let find_candidate_enuminfo ?loc:_loc ei =
  if Globals.Types.mem_type Logic_typing.Enum ei.ename then begin
    match Globals.Types.global Logic_typing.Enum ei.ename with
    | GEnumTag(ei,_) | GEnumTagDecl(ei,_) -> Some ei
    | g ->
      Kernel.fatal
        "Expected enumeration definition instead of %a"
        Cil_datatype.Global.pretty g
  end else None

let find_candidate_varinfo ?loc:_loc vi where =
  try
    Some (Globals.Vars.find_from_astinfo vi.vname where)
  with Not_found -> None

let is_same_opt f o o' =
  match o, o' with
  | None, None -> true
  | Some v, Some v' -> f v v'
  | _ -> false

let rec is_same_type t t' =
  match t, t' with
  | (TVoid _ | TInt _ | TFloat _ | TBuiltin_va_list _), _ ->
    Cil_datatype.TypByName.equal t t'
  | TPtr(t,a), TPtr(t',a') ->
    is_same_type t t' && Cil_datatype.Attributes.equal a a'
  | TArray(t,s,a), TArray(t',s',a') ->
    is_same_type t t' && is_same_opt is_same_exp s s'
    && Cil_datatype.Attributes.equal a a'
  | TFun(rt,l,var,a), TFun(rt', l', var', a') ->
    is_same_type rt rt' &&
    is_same_opt (Logic_utils.is_same_list is_same_formal) l l' &&
    var = var' &&
    Cil_datatype.Attributes.equal a a'
  | TNamed(t,a), TNamed(t',a') ->
    let correspondance = typeinfo_correspondance t in
    (match correspondance with
      | `Not_present -> false
      | `Same t'' -> Cil_datatype.Typeinfo.equal t' t'') &&
    Cil_datatype.Attributes.equal a a'
  | TComp(c,a), TComp(c', a') ->
    let correspondance = compinfo_correspondance c in
    (match correspondance with
     | `Not_present -> false
     | `Same c'' -> Cil_datatype.Compinfo.equal c' c'') &&
    Cil_datatype.Attributes.equal a a'
  | TEnum(e,a), TEnum(e',a') ->
    let correspondance = enuminfo_correspondance e in
    (match correspondance with
     | `Not_present -> false
     | `Same e'' -> Cil_datatype.Enuminfo.equal e' e'') &&
    Cil_datatype.Attributes.equal a a'
  | (TPtr _ | TArray _ | TFun _ | TNamed _ | TComp _ | TEnum _), _ -> false

and is_same_compinfo _ci _ci' = false

and is_same_enuminfo _ei _ei' = false

and is_same_formal (_,t,a) (_,t',a') =
  is_same_type t t' && Cil_datatype.Attributes.equal a a'

and is_same_compound_init (o,i) (o',i') =
  is_same_offset o o' && is_same_init i i'

and is_same_init i i' =
  match i, i' with
  | SingleInit e, SingleInit e' -> is_same_exp e e'
  | CompoundInit (t,l), CompoundInit (t', l') ->
    is_same_type t t' &&
    Logic_utils.is_same_list is_same_compound_init l l'
  | (SingleInit _ | CompoundInit _), _ -> false

and is_same_initinfo i i' = is_same_opt is_same_init i.init i'.init

and is_same_exp _e _e' = false

and is_same_offset _o _o' = false

and typeinfo_correspondance ?loc ti =
  let add ti =
    match find_candidate_type ?loc ti with
    | None -> `Not_present
    | Some ti' ->
      if is_same_type ti.ttype ti'.ttype then `Same ti' else `Not_present
  in
  Typeinfo.memo add ti

and compinfo_correspondance ?loc ci =
  let add ci =
    match find_candidate_compinfo ?loc ci with
    | None -> `Not_present
    | Some ci' ->
      if is_same_compinfo ci ci' then `Same ci' else `Not_present
  in
  Compinfo.memo add ci

and enuminfo_correspondance ?loc ei =
  let add ei =
    match find_candidate_enuminfo ?loc ei with
    | None -> `Not_present
    | Some ei' ->
      if is_same_enuminfo ei ei' then `Same ei' else `Not_present
  in
  Enuminfo.memo add ei

let gvar_correspondance ?loc vi =
  let add vi =
    match find_candidate_varinfo ?loc vi Cil_types.VGlobal with
    | None -> `Not_present
    | Some vi' ->
      let selection = State_selection.singleton Globals.Vars.self in
      let init =
        Project.on ~selection (Orig_project.get()) Globals.Vars.find vi
      in
      let init' = Globals.Vars.find vi' in
      if is_same_initinfo init init' then `Same vi' else `Not_present
  in
  Varinfo.memo add vi

let global_correspondance g =
  match g with
  | GType (ti,loc) -> ignore (typeinfo_correspondance ~loc ti)
  | GCompTag(ci,loc) | GCompTagDecl(ci,loc) ->
    ignore (compinfo_correspondance ~loc ci)
  | GEnumTag(ei,loc) | GEnumTagDecl(ei,loc) ->
    ignore (enuminfo_correspondance ~loc ei)
  | GVar(vi,_,loc) | GVarDecl(vi,loc) ->
    ignore (gvar_correspondance ~loc vi)
  | _ -> ()

let compare_ast prj =
  Orig_project.set prj;
  let ast = Project.on prj Ast.get () in
  Cil.iterGlobals ast global_correspondance
