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

(* for kernel function, we are a bit more precise than a yes/no answer.
   More precisely, we check whether a function has the same spec,
   the same body, and whether its callees have changed (provided
   the body itself is identical, otherwise, there's no point in checking
   the callees.
*)
type partial_correspondance =
  [ `Spec_changed (* body and callees haven't changed *)
  | `Body_changed (* spec hasn't changed *)
  | `Callees_changed (* spec and body haven't changed *)
  | `Callees_spec_changed (* body hasn't changed *)
  ]

type body_correspondance =
  [ `Body_changed
  | `Callees_changed
  | `Same_body
  ]

let (<=>) res (cmp,x,y) = if res <> 0 then res else cmp x y

let compare_pc pc1 pc2 =
  match pc1, pc2 with
  | `Spec_changed, `Spec_changed -> 0
  | `Spec_changed, _ -> -1
  | _, `Spec_changed -> 1
  | `Body_changed, `Body_changed -> 0
  | `Body_changed, _ -> -1
  | _, `Body_changed -> 1
  | `Callees_changed, `Callees_changed -> -1
  | `Callees_changed, _ -> -1
  | _, `Callees_changed -> 1
  | `Callees_spec_changed, `Callees_spec_changed -> 0

let string_of_pc = function
  | `Spec_changed -> "Spec_changed"
  | `Body_changed -> "Body_changed"
  | `Callees_changed -> "Callees_changed"
  | `Callees_spec_changed -> "Callees_spec_changed"

let pretty_pc fmt =
  let open Format in
  function
  | `Spec_changed -> pp_print_string fmt "(spec changed)"
  | `Body_changed -> pp_print_string fmt "(body_changed)"
  | `Callees_changed -> pp_print_string fmt "(callees changed)"
  | `Callees_spec_changed -> pp_print_string fmt "(callees and spec changed)"

type kf_correspondance =
  [ kernel_function correspondance
  | `Partial of kernel_function * partial_correspondance
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
      `Partial (kf,`Spec_changed)
      :: (C.reprs :> t list)
    let compare x y =
      match x,y with
      | `Partial (kf1,flags1), `Partial(kf2,flags2) ->
        Kernel_function.compare kf1 kf2 <=> (compare_pc,flags1,flags2)
      | `Partial _, _ -> 1
      | _, `Partial _ -> -1
      | (#correspondance as x), (#correspondance as y) -> C.compare x y
    let equal = Datatype.from_compare
    let hash = function
      | `Partial(kf,_) -> 57 * (Kernel_function.hash kf)
      | #correspondance as x -> C.hash x
    let internal_pretty_code p fmt = function
      | `Partial (kf,flags) ->
        let pp fmt =
          Format.fprintf fmt
            "`Partial (%a,%s)"
            (Kernel_function.internal_pretty_code Type.Call) kf
            (string_of_pc flags)
        in
        Type.par p Call fmt pp
      | #correspondance as x -> C.internal_pretty_code p fmt x
    let pretty fmt = function
      | `Partial(kf,flags) ->
        Format.fprintf fmt "-> %a %a"
          Kernel_function.pretty kf
          pretty_pc flags
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
type is_same_env =
  {
    compinfo: compinfo Cil_datatype.Compinfo.Map.t;
    kernel_function: kernel_function Kernel_function.Map.t;
    logic_info: logic_info Cil_datatype.Logic_info.Map.t;
    logic_type_info: logic_type_info Cil_datatype.Logic_type_info.Map.t;
  }

module Build(H:Datatype.S_with_collections)(D:Datatype.S) =
  State_builder.Hashtbl(H.Hashtbl)(D)
    (Info(struct let name = "Ast_diff." ^ D.name end))

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

let find_candidate_func ?loc:_loc kf =
  try
    Some (Globals.Functions.find_by_name (Kf.get_name kf))
  with Not_found -> None

let find_candidate_logic_type ?loc:_loc ti =
  try
    Some (Logic_env.find_logic_type ti.lt_name)
  with Not_found -> None

let is_same_opt f o o' env =
  match o, o' with
  | None, None -> true
  | Some v, Some v' -> f v v' env
  | _ -> false

let rec is_same_list f l l' env =
  match l, l' with
  | [], [] -> true
  | h::t, h'::t' ->
    f h h' env && is_same_list f t t' env
  | _ -> false

let rec is_same_type t t' env =
  match t, t' with
  | (TVoid _ | TInt _ | TFloat _ | TBuiltin_va_list _), _ ->
    Cil_datatype.TypByName.equal t t'
  | TPtr(t,a), TPtr(t',a') ->
    is_same_type t t' env && Cil_datatype.Attributes.equal a a'
  | TArray(t,s,a), TArray(t',s',a') ->
    is_same_type t t' env &&
    is_same_opt is_same_exp s s' env &&
    Cil_datatype.Attributes.equal a a'
  | TFun(rt,l,var,a), TFun(rt', l', var', a') ->
    is_same_type rt rt' env &&
    is_same_opt (is_same_list is_same_formal) l l' env &&
    (var = var') &&
    Cil_datatype.Attributes.equal a a'
  | TNamed(t,a), TNamed(t',a') ->
    let correspondance = typeinfo_correspondance t env in
    (match correspondance with
     | `Not_present -> false
     | `Same t'' -> Cil_datatype.Typeinfo.equal t' t'') &&
    Cil_datatype.Attributes.equal a a'
  | TComp(c,a), TComp(c', a') ->
    let correspondance = compinfo_correspondance c env in
    (match correspondance with
     | `Not_present -> false
     | `Same c'' -> Cil_datatype.Compinfo.equal c' c'') &&
    Cil_datatype.Attributes.equal a a'
  | TEnum(e,a), TEnum(e',a') ->
    let correspondance = enuminfo_correspondance e env in
    (match correspondance with
     | `Not_present -> false
     | `Same e'' -> Cil_datatype.Enuminfo.equal e' e'') &&
    Cil_datatype.Attributes.equal a a'
  | (TPtr _ | TArray _ | TFun _ | TNamed _ | TComp _ | TEnum _), _ -> false

and is_same_compinfo _ci _ci' _env = false

and is_same_enuminfo _ei _ei' _env = false

and is_same_formal (_,t,a) (_,t',a') env =
  is_same_type t t' env && Cil_datatype.Attributes.equal a a'

and is_same_compound_init (o,i) (o',i') env =
  is_same_offset o o' env && is_same_init i i' env

and is_same_init i i' env =
  match i, i' with
  | SingleInit e, SingleInit e' -> is_same_exp e e' env
  | CompoundInit (t,l), CompoundInit (t', l') ->
    is_same_type t t' env &&
    (is_same_list is_same_compound_init) l l' env
  | (SingleInit _ | CompoundInit _), _ -> false

and is_same_initinfo i i' env = is_same_opt is_same_init i.init i'.init env

and is_same_exp _e _e' _env = false

and is_same_offset _o _o' _env = false

and is_same_funspec _s _s' _env = false

and is_same_fundec _f _f' _env: body_correspondance = `Body_changed

and is_same_logic_type _t _t' _env = false

and is_same_logic_param _lv _lv' _env = false

and is_same_logic_info _li _li' _env = false

and is_same_logic_type_info _ti _ti' _env = false

and is_same_model_info _mi _mi' _env = false

(* because of overloading, we have to check for a corresponding profile,
   leading to potentially recursive calls to is_same_* functions. *)
and find_candidate_logic_info ?loc:_loc li env =
  let candidates = Logic_env.find_all_logic_functions li.l_var_info.lv_name in
  let find_one li' =
    is_same_list is_same_logic_param li.l_profile li'.l_profile env
  in
  let rec extract l =
    match l with
    | [] -> None
    | li' :: tl -> if find_one li' then Some li' else extract tl
  in
  match extract candidates with
  | None -> None
  | Some li' ->
    let res = is_same_opt is_same_logic_type li.l_type li'.l_type env in
    if res then Some li' else None

and find_candidate_model_info ?loc:_loc mi env =
  let candidates = Logic_env.find_all_model_fields mi.mi_name in
  let find_one mi' =
    is_same_type mi.mi_base_type mi'.mi_base_type env
  in
  let rec aux = function
    | [] -> None
    | mi' :: tl -> if find_one mi' then Some mi' else aux tl
  in
  aux candidates

and typeinfo_correspondance ?loc ti env =
  let add ti =
    match find_candidate_type ?loc ti with
    | None -> `Not_present
    | Some ti' ->
      let res = is_same_type ti.ttype ti'.ttype env in
      if res then `Same ti' else `Not_present
  in
  Typeinfo.memo add ti

and compinfo_correspondance ?loc ci env =
  let add ci =
    match find_candidate_compinfo ?loc ci with
    | None -> `Not_present
    | Some ci' ->
      let env' =
        {env with compinfo = Cil_datatype.Compinfo.Map.add ci ci' env.compinfo}
      in
      let res = is_same_compinfo ci ci' env' in
      if res then `Same ci' else `Not_present
  in
  match Cil_datatype.Compinfo.Map.find_opt ci env.compinfo with
  | Some ci' -> `Same ci'
  | None -> Compinfo.memo add ci

and enuminfo_correspondance ?loc ei env =
  let add ei =
    match find_candidate_enuminfo ?loc ei with
    | None -> `Not_present
    | Some ei' ->
      if is_same_enuminfo ei ei' env then `Same ei' else `Not_present
  in
  Enuminfo.memo add ei

and gfun_correspondance ?loc vi env =
  let selection =
    State_selection.(
      union
        (with_dependencies Kernel_function.self)
        (union
           (with_dependencies Annotations.funspec_state)
           (with_dependencies Annotations.code_annot_state)))
  in
  let kf =
    Project.on ~selection (Orig_project.get()) Globals.Functions.get vi
  in
  let add kf =
    match find_candidate_func ?loc kf with
    | None -> `Not_present
    | Some kf' ->
      let env' =
        { env with kernel_function = Kf.Map.add kf kf' env.kernel_function }
      in
      let same_spec = is_same_funspec kf.spec kf'.spec env' in
      let same_body =
        match (Kf.has_definition kf, Kf.has_definition kf') with
        | false, false -> `Same_body
        | false, true | true, false -> `Body_changed
        | true, true ->
          is_same_fundec (Kf.get_definition kf) (Kf.get_definition kf') env'
      in
      match same_spec, same_body with
      | false, `Body_changed -> `Not_present
      | false, `Callees_changed -> `Partial(kf',`Callees_spec_changed)
      | false, `Same_body -> `Partial(kf', `Spec_changed)
      | true, `Same_body -> `Same kf'
      | true, ((`Body_changed|`Callees_changed) as c) -> `Partial(kf', c)
  in
  match Kf.Map.find_opt kf env.kernel_function with
  | Some kf' -> `Same kf'
  | None -> Kernel_function.memo add kf

and logic_info_correspondance ?loc li env =
  let add li =
    match find_candidate_logic_info ?loc li env with
    | None -> `Not_present
    | Some li' ->
      let env =
        { env with
          logic_info = Cil_datatype.Logic_info.Map.add li li' env.logic_info }
      in
      let res = is_same_logic_info li li' env in
      if res then `Same li' else `Not_present
  in
  match Cil_datatype.Logic_info.Map.find_opt li env.logic_info with
  | Some li' -> `Same li'
  | None -> Logic_info.memo add li

and logic_type_correspondance ?loc ti env =
  let add ti =
    match find_candidate_logic_type ?loc ti with
    | None -> `Not_present
    | Some ti' ->
      let env =
        { env with
          logic_type_info =
            Cil_datatype.Logic_type_info.Map.add ti ti' env.logic_type_info }
      in
      let res = is_same_logic_type_info ti ti' env in
      if res then `Same ti' else `Not_present
  in
  match Cil_datatype.Logic_type_info.Map.find_opt ti env.logic_type_info with
  | Some ti' -> `Same ti'
  | None -> Logic_type_info.memo add ti

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
      let res = is_same_initinfo init init' empty_env in
      if res then `Same vi' else `Not_present
  in
  Varinfo.memo add vi

let model_info_correspondance ?loc mi =
  let add mi =
    match find_candidate_model_info ?loc mi empty_env with
    | None -> `Not_present
    | Some mi' ->
      let res = is_same_model_info mi mi' empty_env in
      if res then `Same mi' else `Not_present
  in
  Model_info.memo add mi

let rec gannot_correspondance =
  function
  | Dfun_or_pred (li,loc) ->
    ignore (logic_info_correspondance ~loc li empty_env)

  | Dvolatile _ -> ()
  (* reading and writing function themselves will be checked elsewhere. *)

  | Daxiomatic(_,l,_,_) ->
    List.iter gannot_correspondance l
  | Dtype (ti,loc) -> ignore (logic_type_correspondance ~loc ti empty_env)
  | Dlemma _ -> ()
  (* TODO: we currently do not have any appropriate structure for
     storing information about lemmas. *)
  | Dinvariant(li, loc) ->
    ignore (logic_info_correspondance ~loc li empty_env)
  | Dtype_annot(li,loc) ->
    ignore (logic_info_correspondance ~loc li empty_env)
  | Dmodel_annot (mi,loc) ->
    ignore (model_info_correspondance ~loc mi)
  | Dextended _ -> ()
(* TODO: provide mechanism for extension themselves
   to give relevant information. *)

let global_correspondance g =
  match g with
  | GType (ti,loc) -> ignore (typeinfo_correspondance ~loc ti empty_env)
  | GCompTag(ci,loc) | GCompTagDecl(ci,loc) ->
    ignore (compinfo_correspondance ~loc ci empty_env)
  | GEnumTag(ei,loc) | GEnumTagDecl(ei,loc) ->
    ignore (enuminfo_correspondance ~loc ei empty_env)
  | GVar(vi,_,loc) | GVarDecl(vi,loc) ->
    ignore (gvar_correspondance ~loc vi)
  | GFunDecl(_,vi,loc) -> ignore (gfun_correspondance ~loc vi empty_env)
  | GFun(f,loc) -> ignore (gfun_correspondance ~loc f.svar empty_env)
  | GAnnot (g,_) -> gannot_correspondance g
  | GAsm _ | GPragma _ | GText _ -> ()

let compare_ast prj =
  Orig_project.set prj;
  let ast = Project.on prj Ast.get () in
  Cil.iterGlobals ast global_correspondance
