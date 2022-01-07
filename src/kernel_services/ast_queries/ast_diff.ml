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

(* Map of symbols under analysis, in case of recursion.
   Note that this can only happen with aggregate types, logic
   types, and function (both C and ACSL). Other symbols must be
   correctly ordered in a well-formed AST
*)
[@@@ ocaml.warning "-69"] (* WIP: currently not all fields are used *)
type is_same_env =
  {
    compinfo: compinfo Cil_datatype.Compinfo.Map.t;
    kernel_function: kernel_function Kernel_function.Map.t;
    logic_info: logic_info Cil_datatype.Logic_info.Map.t;
    logic_type_info: logic_type_info Cil_datatype.Logic_type_info.Map.t;
  }

module Build(H:Datatype.S_with_collections)(D:Datatype.S) = struct
  include
    State_builder.Hashtbl(H.Hashtbl)(D)
      (Info(struct let name = "Ast_diff." ^ D.name end))

  let memo_env mk_val key env =
    if mem key then find key, env
    else let (data, _) as res = mk_val key env in
      add key data; res
end

module Build_correspondance(H:Datatype.S_with_collections) =
  Build(H)(Correspondance.Make(H))

module Varinfo = Build_correspondance(Cil_datatype.Varinfo)

module Compinfo = Build_correspondance(Cil_datatype.Compinfo)

module Enuminfo = Build_correspondance(Cil_datatype.Enuminfo)

module Enumitem = Build_correspondance(Cil_datatype.Enumitem)

module Typeinfo = Build_correspondance(Cil_datatype.Typeinfo)

module Stmt = Build_correspondance(Cil_datatype.Stmt)

module Logic_info = Build_correspondance(Cil_datatype.Logic_info)

module Logic_type_info = Build_correspondance(Cil_datatype.Logic_type_info)

module Fieldinfo = Build_correspondance(Cil_datatype.Fieldinfo)

module Model_info = Build_correspondance(Cil_datatype.Model_info)

module Logic_var = Build_correspondance(Cil_datatype.Logic_var)

module Kf = Kernel_function

module Kernel_function = Build(Kernel_function)(Kf_correspondance)

module Fundec = Build_correspondance(Cil_datatype.Fundec)

let empty_env =
  { compinfo = Cil_datatype.Compinfo.Map.empty;
    kernel_function = Kf.Map.empty;
    logic_info = Cil_datatype.Logic_info.Map.empty;
    logic_type_info = Cil_datatype.Logic_type_info.Map.empty;
  }

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

let (&&>) (res,env) f = if res then f env else false, env
let (&&|) env f = f env
let (&&&) (res,env) b = res && b, env

let is_same_opt f o o' env =
  match o, o' with
  | None, None -> true, env
  | Some v, Some v' -> f v v' env
  | _ -> false, env

let rec is_same_list f l l' env =
  match l, l' with
  | [], [] -> true, env
  | h::t, h'::t' ->
    env &&| f h h' &&> is_same_list f t t'
  | _ -> false, env

let rec is_same_type t t' env =
  match t, t' with
  | (TVoid _ | TInt _ | TFloat _ | TBuiltin_va_list _), _ ->
    Cil_datatype.TypByName.equal t t', env
  | TPtr(t,a), TPtr(t',a') ->
    env &&| is_same_type t t' &&& Cil_datatype.Attributes.equal a a'
  | TArray(t,s,a), TArray(t',s',a') ->
    env &&|
    is_same_type t t' &&>
    is_same_opt is_same_exp s s' &&&
    Cil_datatype.Attributes.equal a a'
  | TFun(rt,l,var,a), TFun(rt', l', var', a') ->
    env &&|
    is_same_type rt rt' &&>
    is_same_opt (is_same_list is_same_formal) l l' &&&
    (var = var') &&&
    Cil_datatype.Attributes.equal a a'
  | TNamed(t,a), TNamed(t',a') ->
    let correspondance, env = typeinfo_correspondance t env in
    (match correspondance with
     | `Not_present -> false, env
     | `Same t'' -> Cil_datatype.Typeinfo.equal t' t'',env) &&&
    Cil_datatype.Attributes.equal a a'
  | TComp(c,a), TComp(c', a') ->
    let correspondance, env = compinfo_correspondance c env in
    (match correspondance with
     | `Not_present -> false, env
     | `Same c'' -> Cil_datatype.Compinfo.equal c' c'', env) &&&
    Cil_datatype.Attributes.equal a a'
  | TEnum(e,a), TEnum(e',a') ->
    let correspondance, env = enuminfo_correspondance e env in
    (match correspondance with
     | `Not_present -> false, env
     | `Same e'' -> Cil_datatype.Enuminfo.equal e' e'', env) &&&
    Cil_datatype.Attributes.equal a a'
  | (TPtr _ | TArray _ | TFun _ | TNamed _ | TComp _ | TEnum _), _ -> false, env

and is_same_compinfo _ci _ci' env = false, env

and is_same_enuminfo _ei _ei' env = false, env

and is_same_formal (_,t,a) (_,t',a') env =
  is_same_type t t' env &&& Cil_datatype.Attributes.equal a a'

and is_same_compound_init (o,i) (o',i') env =
  is_same_offset o o' env &&> is_same_init i i'

and is_same_init i i' env =
  match i, i' with
  | SingleInit e, SingleInit e' -> is_same_exp e e' env
  | CompoundInit (t,l), CompoundInit (t', l') ->
    is_same_type t t' env &&>
    (is_same_list is_same_compound_init) l l'
  | (SingleInit _ | CompoundInit _), _ -> false, env

and is_same_initinfo i i' = is_same_opt is_same_init i.init i'.init

and is_same_exp _e _e' env = false, env

and is_same_offset _o _o' env = false, env

and typeinfo_correspondance ?loc ti env =
  let add ti env =
    match find_candidate_type ?loc ti with
    | None -> `Not_present, env
    | Some ti' ->
      let res, env = is_same_type ti.ttype ti'.ttype env in
      (if res then `Same ti' else `Not_present), env
  in
  Typeinfo.memo_env add ti env

and compinfo_correspondance ?loc ci env =
  let add ci env =
    match find_candidate_compinfo ?loc ci with
    | None -> `Not_present, env
    | Some ci' ->
      let res, env = is_same_compinfo ci ci' env in
      (if res then `Same ci' else `Not_present), env
  in
  match Cil_datatype.Compinfo.Map.find_opt ci env.compinfo with
  | Some ci' -> `Same ci', env
  | None -> Compinfo.memo_env add ci env

and enuminfo_correspondance ?loc ei env =
  let add ei env =
    match find_candidate_enuminfo ?loc ei with
    | None -> `Not_present, env
    | Some ei' ->
      let res, env = is_same_enuminfo ei ei' env in
      (if res then `Same ei' else `Not_present),env
  in
  Enuminfo.memo_env add ei env

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
      let res,_ = is_same_initinfo init init' empty_env in
      if res then `Same vi' else `Not_present
  in
  Varinfo.memo add vi

let global_correspondance g =
  match g with
  | GType (ti,loc) -> ignore (typeinfo_correspondance ~loc ti empty_env)
  | GCompTag(ci,loc) | GCompTagDecl(ci,loc) ->
    ignore (compinfo_correspondance ~loc ci empty_env)
  | GEnumTag(ei,loc) | GEnumTagDecl(ei,loc) ->
    ignore (enuminfo_correspondance ~loc ei empty_env)
  | GVar(vi,_,loc) | GVarDecl(vi,loc) ->
    ignore (gvar_correspondance ~loc vi)
  | GFunDecl(_,_vi,_loc) -> ()
  | GFun(_f,_loc) -> ()
  | _ -> ()

let compare_ast prj =
  Orig_project.set prj;
  let ast = Project.on prj Ast.get () in
  Cil.iterGlobals ast global_correspondance
