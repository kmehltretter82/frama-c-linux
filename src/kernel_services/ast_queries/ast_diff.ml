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

module Correspondance_input =
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

module Correspondance=Datatype.Polymorphic(Correspondance_input)

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

type 'a code_correspondance =
  [ 'a correspondance
  | `Partial of 'a * partial_correspondance
  ]

module Code_correspondance_input =
struct
  type 'a t = 'a code_correspondance
  let name a = Type.name a ^ " code_correspondance"
  let module_name = "Code_correspondance"
  let structural_descr _ = Structural_descr.t_abstract
  let reprs = Correspondance_input.reprs
  let mk_equal eq x y =
    match x,y with
    | `Partial(x,pc), `Partial(x',pc') -> eq x x' && (compare_pc pc pc' = 0)
    | `Partial _, _ | _, `Partial _ -> false
    | (#correspondance as c), (#correspondance as c') ->
      Correspondance_input.mk_equal eq c c'

  let mk_compare cmp x y =
    match x,y with
    | `Partial(x,pc), `Partial(x',pc') ->
      cmp x x' <=> (compare_pc,pc,pc')
    | `Partial _, `Same _ -> -1
    | `Same _, `Partial _ -> 1
    | `Partial _, `Not_present -> 1
    | `Not_present, `Partial _ -> -1
    | (#correspondance as c), (#correspondance as c') ->
      Correspondance_input.mk_compare cmp c c'

  let mk_hash hash = function
    | `Partial (x,_) -> 57 * hash x
    | #correspondance as x -> Correspondance_input.mk_hash hash x

  let map f = function
    | `Partial(x,pc) -> `Partial(f x,pc)
    | (#correspondance as x) -> Correspondance_input.map f x

  let mk_internal_pretty_code pp prec fmt = function
    | `Partial (x,flags) ->
      let pp fmt =
        Format.fprintf fmt "`Partial (%a,%s)"
          (pp Type.Call) x (string_of_pc flags)
      in
      Type.par prec Call fmt pp
    | #correspondance as x ->
      Correspondance_input.mk_internal_pretty_code pp prec fmt x

  let mk_pretty pp fmt = function
    | `Partial(x,flags) ->
      Format.fprintf fmt "-> %a %a" pp x pretty_pc flags
    | #correspondance as x -> Correspondance_input.mk_pretty pp fmt x

  let mk_varname f = function
    | `Partial (x,_) -> f x ^ "_pc"
    | #correspondance as x -> Correspondance_input.mk_varname f x

  let mk_mem_project f p = function
    | `Partial (x,_) -> f p x
    | #correspondance as x -> Correspondance_input.mk_mem_project f p x
end

module Code_correspondance =
  Datatype.Polymorphic(Code_correspondance_input)

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
    local_vars: varinfo Cil_datatype.Varinfo.Map.t;
    logic_info: logic_info Cil_datatype.Logic_info.Map.t;
    logic_type_info: logic_type_info Cil_datatype.Logic_type_info.Map.t;
    logic_local_vars: logic_var Cil_datatype.Logic_var.Map.t;
  }

module Build(H:Datatype.S_with_collections)(D:Datatype.S) =
  State_builder.Hashtbl(H.Hashtbl)(D)
    (Info(struct let name = "Ast_diff." ^ D.name end))

module Build_correspondance(H:Datatype.S_with_collections) =
  Build(H)(Correspondance.Make(H))

module Build_code_correspondance(H:Datatype.S_with_collections) =
  Build(H)(Code_correspondance.Make(H))

module Varinfo = Build_correspondance(Cil_datatype.Varinfo)

module Compinfo = Build_correspondance(Cil_datatype.Compinfo)

module Enuminfo = Build_correspondance(Cil_datatype.Enuminfo)

module Enumitem = Build_correspondance(Cil_datatype.Enumitem)

module Typeinfo = Build_correspondance(Cil_datatype.Typeinfo)

module Stmt = Build_code_correspondance(Cil_datatype.Stmt)

module Logic_info = Build_correspondance(Cil_datatype.Logic_info)

module Logic_type_info = Build_correspondance(Cil_datatype.Logic_type_info)

module Fieldinfo = Build_correspondance(Cil_datatype.Fieldinfo)

module Model_info = Build_correspondance(Cil_datatype.Model_info)

module Logic_var = Build_correspondance(Cil_datatype.Logic_var)

module Kf = Kernel_function

module Kernel_function = Build_code_correspondance(Kernel_function)

module Fundec = Build_correspondance(Cil_datatype.Fundec)

let (&&>) (res,env) f =
  match res with
  | `Body_changed -> `Body_changed, env
  | `Same_body -> f env
  | `Callees_changed ->
    let res', env = f env in
    match res' with
    | `Body_changed -> `Body_changed, env
    | `Same_body | `Callees_changed -> `Callees_changed, env

let empty_env =
  { compinfo = Cil_datatype.Compinfo.Map.empty;
    kernel_function = Kf.Map.empty;
    local_vars = Cil_datatype.Varinfo.Map.empty;
    logic_info = Cil_datatype.Logic_info.Map.empty;
    logic_type_info = Cil_datatype.Logic_type_info.Map.empty;
    logic_local_vars = Cil_datatype.Logic_var.Map.empty;
  }

let add_locals f f' env =
  let add_one env v v' =
    { env with local_vars = Cil_datatype.Varinfo.Map.add v v' env.local_vars }
  in
  List.fold_left2 add_one env f f'

let add_logic_prms p p' env =
  let add_one env lv lv' =
    { env with
      logic_local_vars =
        Cil_datatype.Logic_var.Map.add lv lv' env.logic_local_vars }
  in
  List.fold_left2 add_one env p p'

let formals_correspondance f f' =
  let add_one v v' = Varinfo.add v (`Same v') in
  List.iter2 add_one f f'

let logic_prms_correspondance p p' =
  let add_one lv lv' =
    Logic_var.add lv (`Same lv') in
  List.iter2 add_one p p'

let update_stmt_correspondance s s' (corres,_) =
  match corres with
  | `Same_body -> Stmt.add s (`Same s')
  | (`Spec_changed | `Callees_changed | `Callees_spec_changed) as c ->
    Stmt.add s (`Partial(s',(c:>partial_correspondance)))
  | `Body_changed -> ()

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

let is_same_pair f1 f2 (x1,x2) (y1,y2) env = f1 x1 y1 env && f2 x2 y2 env

let rec is_same_list f l l' env =
  match l, l' with
  | [], [] -> true
  | h::t, h'::t' ->
    f h h' env && is_same_list f t t' env
  | _ -> false

module Unop = struct
  type t = [%import: Cil_types.unop] [@@deriving eq]
end

module Binop = struct
  type t = [%import: Cil_types.binop] [@@deriving eq]
end

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

and is_same_local_init i i' env =
  match i, i' with
  | AssignInit i, AssignInit i' ->
    if is_same_init i i' env then `Same_body
    else `Body_changed
  | (ConsInit(c,args,Plain_func), ConsInit(c',args',Plain_func))
  | (ConsInit(c,args,Constructor),ConsInit(c',args',Constructor))  ->
    if is_same_varinfo c c' env &&
       is_same_list is_same_exp args args' env
    then begin
      match gfun_correspondance c env with
      | `Partial _ | `Not_present -> `Callees_changed
      | `Same _ -> `Same_body
    end else `Body_changed
  | (AssignInit _| ConsInit _), _ -> `Body_changed

and is_same_exp e e' env =
  match e.enode, e'.enode with
  | Const c, Const c' -> Cil_datatype.Constant.equal c c'
  | Lval lv, Lval lv' -> is_same_lval lv lv' env
  | SizeOf t, SizeOf t' -> is_same_type t t' env
  | SizeOfE e, SizeOfE e' -> is_same_exp e e' env
  | SizeOfStr s, SizeOfStr s' -> String.length s = String.length s'
  | AlignOf t, AlignOf t' -> is_same_type t t' env
  | AlignOfE e, AlignOfE e' -> is_same_exp e e' env
  | UnOp(op,e,t), UnOp(op',e',t') ->
    Unop.equal op op' && is_same_exp e e' env && is_same_type t t' env
  | BinOp(op,e1,e2,t), BinOp(op',e1',e2',t') ->
    Binop.equal op op' && is_same_exp e1 e1' env && is_same_exp e2 e2' env
    && is_same_type t t' env
  | CastE(t,e), CastE(t',e') -> is_same_type t t' env && is_same_exp e e' env
  | AddrOf lv, AddrOf lv' -> is_same_lval lv lv' env
  | StartOf lv, StartOf lv' -> is_same_lval lv lv' env
  | Info _, Info _ -> false (* should be removed from AST anyway *)
  | (Const _ | Lval _ | SizeOf _ | SizeOfE _ | SizeOfStr _ | AlignOf _
    | AlignOfE _ | UnOp _ | BinOp _  | CastE _ | AddrOf _ | StartOf _
    | Info _), _ -> false

and is_same_lval (_h,_o) (_h',_o') _env = false

and is_same_offset _o _o' _env = false

and is_same_extended_asm a a' env =
  let is_same_out (_,c,l) (_,c',l') env =
    Datatype.String.equal c c' && is_same_lval l l' env
  and is_same_in (_,c,e) (_,c',e') env =
    Datatype.String.equal c c' && is_same_exp e e' env
  in
  is_same_list is_same_out a.asm_outputs a'.asm_outputs env &&
  is_same_list is_same_in a.asm_inputs a'.asm_inputs env &&
  is_same_list
    (fun s1 s2 _ -> Datatype.String.equal s1 s2)
    a.asm_clobbers a'.asm_clobbers env
(* we don't check goto targets, as explained below for goto statements. *)

and is_same_instr i i' env: body_correspondance*is_same_env =
  match i,i' with
  | Set(lv,e,_), Set(lv',e',_) ->
    if is_same_lval lv lv' env && is_same_exp e e' env then
      `Same_body, env
    else
      `Body_changed, env
  | Call(lv,f,args,_), Call(lv',f',args',_) ->
    if is_same_opt is_same_lval lv lv' env &&
       is_same_exp f f' env &&
       is_same_list is_same_exp args args' env
    then begin
      match f.enode with
      | Lval(Var f,NoOffset) ->
        (match gfun_correspondance f env with
         | `Partial _ | `Not_present -> `Callees_changed, env
         | `Same _ -> `Same_body, env)
      | _ -> `Callees_changed, env
      (* by default, we consider that indirect call might have changed *)
    end else `Body_changed, env
  | Local_init(v,i,_), Local_init(v',i',_) ->
    if is_same_varinfo v v' env then begin
      let env = add_locals [v] [v'] env in
      let res = is_same_local_init i i' env in
      res, env
    end else `Body_changed, env
  | Asm(a,c,e,_), Asm(a',c',e',_) ->
    if Cil_datatype.Attributes.equal a a' &&
       is_same_list (fun s1 s2 _ -> Datatype.String.equal s1 s2) c c' env &&
       is_same_opt is_same_extended_asm e e' env
    then
      `Same_body, env
    else `Body_changed, env
  | Skip _, Skip _ -> `Same_body, env
  | Code_annot _, Code_annot _ ->
    (* should not be present in normalized AST *)
    `Same_body, env
  | _ -> `Body_changed, env

and is_same_instr_list l l' env =
  match l, l' with
  | [], [] -> `Same_body, env
  | [], _ | _, [] -> `Body_changed, env
  | i::tl, i'::tl' ->
    is_same_instr i i' env &&> is_same_instr_list tl tl'

and is_same_stmt s s' env =
  if s.ghost = s'.ghost && Cil_datatype.Attributes.equal s.sattr s'.sattr then
    begin
      let res =
        match s.skind,s'.skind with
        | Instr i, Instr i' -> is_same_instr i i' env
        | Return (r,_), Return(r', _) ->
          if is_same_opt is_same_exp r r' env then `Same_body, env
          else `Body_changed, env
        | Goto (_s,_), Goto(_s',_) -> `Same_body, env
        | Break _, Break _ -> `Same_body, env
        | Continue _, Continue _ -> `Same_body, env
        | If(e,b1,b2,_), If(e',b1',b2',_) ->
          if is_same_exp e e' env then begin
            is_same_block b1 b1' env &&>
            is_same_block b2 b2'
          end else `Body_changed, env
        | Switch(e,b,_,_), Switch(e',b',_,_) ->
          if is_same_exp e e' env then begin
            is_same_block b b' env
          end else `Body_changed, env
        | Loop(_,b,_,_,_), Loop(_,b',_,_,_) ->
          is_same_block b b' env
        | Block b, Block b' ->
          is_same_block b b' env
        | UnspecifiedSequence l, UnspecifiedSequence l' ->
          let b = Cil.block_from_unspecified_sequence l in
          let b' = Cil.block_from_unspecified_sequence l' in
          is_same_block b b' env
        | Throw (e,_), Throw (e',_) ->
          if is_same_opt (is_same_pair is_same_exp is_same_type) e e' env then
            `Same_body, env
          else `Body_changed, env
        | TryCatch (b,c,_), TryCatch(b',c',_) ->
          let rec is_same_catch_list l l' env =
            match l, l' with
            | [], [] -> `Same_body, env
            | [],_ | _, [] -> `Body_changed, env
            | (bind, b) :: tl, (bind', b') :: tl' ->
              is_same_binder bind bind' env &&>
              is_same_block b b' &&>
              is_same_catch_list tl tl'
          in
          is_same_block b b' env &&> is_same_catch_list c c'
        | TryFinally(b1,b2,_), TryFinally(b1',b2',_) ->
          is_same_block b1 b1' env &&>
          (is_same_block b2 b2')
        | TryExcept(b1,(h,e),b2,_), TryExcept(b1',(h',e'),b2',_) ->
          if is_same_exp e e' env then begin
            is_same_block b1 b1' env &&>
            is_same_instr_list h h' &&>
            is_same_block b2 b2'
          end else `Body_changed, env
        | _ -> `Body_changed, env
      in
      update_stmt_correspondance s s' res; res
    end else `Body_changed, env

(* is_same_block will return its modified environment in order
   to update correspondance table with respect to locals, in case
   the body of the enclosing function is unchanged. *)
and is_same_block b b' env =
  let local_decls = List.filter (fun x -> not x.vdefined) b.blocals in
  let local_decls' = List.filter (fun x -> not x.vdefined) b'.blocals in
  if is_same_list is_same_varinfo local_decls local_decls' env &&
     Cil_datatype.Attributes.equal b.battrs b'.battrs
  then begin
    let env = add_locals local_decls local_decls' env in
    let rec is_same_stmts l l' env =
      match l, l' with
      | [], [] -> `Same_body,env
      | [], _ | _, [] -> `Body_changed, env
      | s :: tl, s' :: tl' ->
        is_same_stmt s s' env &&> (is_same_stmts tl tl')
    in
    is_same_stmts b.bstmts b'.bstmts env
  end else `Body_changed, env

and is_same_binder b b' env =
  match b, b' with
  | Catch_exn(v,conv), Catch_exn(v', conv') ->
    if is_same_varinfo v v' env then begin
      let env = add_locals [v] [v'] env in
      let rec is_same_conv l l' env =
        match l, l' with
        | [], [] -> `Same_body, env
        | [], _ | _, [] -> `Body_changed, env
        | (v,b)::tl, (v',b')::tl' ->
          if is_same_varinfo v v' env then begin
            let env = add_locals [v] [v'] env in
            is_same_block b b' env &&>
            (is_same_conv tl tl')
          end else `Body_changed, env
      in
      is_same_conv conv conv' env
    end else `Body_changed, env
  | Catch_all, Catch_all -> `Same_body, env
  | (Catch_exn _ | Catch_all), _ -> `Body_changed, env

and is_same_funspec _s _s' _env = false

(* correspondance of formals is supposed to have already been checked,
   and formals mapping to have been put in the local env
*)
and is_same_fundec f f' env: body_correspondance =
  let res, env = is_same_block f.sbody f'.sbody env in
  (* Since we add the locals only if the body is the same,
     we have explored all nodes, and added all locals bindings.
     Otherwise, is_same_block would have returned `Body_changed.
     Hence [Not_found] cannot be raised. *)
  let add_local v =
    let v' = Cil_datatype.Varinfo.Map.find v env.local_vars in
    Varinfo.add v (`Same v')
  in
  (match res with
   | `Same_body | `Callees_changed ->
     List.iter add_local f.slocals
   | `Body_changed -> ());
  res

and is_same_logic_type _t _t' _env = false

and is_same_logic_param _lv _lv' _env = false

and is_same_logic_info _li _li' _env = false

and is_same_logic_type_info _ti _ti' _env = false

and is_same_model_info _mi _mi' _env = false

(* only for locals and formals. Globals are treated by
   gvar_correspondance below. *)
and is_same_varinfo vi vi' env =
  is_same_type vi.vtype vi'.vtype env &&
  Cil_datatype.Attributes.equal vi.vattr vi'.vattr

and is_same_logic_var lv lv' env =
  is_same_logic_type lv.lv_type lv'.lv_type env &&
  Cil_datatype.Attributes.equal lv.lv_attr lv'.lv_attr

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
      let formals = Kf.get_formals kf in
      let formals' = Kf.get_formals kf' in
      if is_same_list is_same_varinfo formals formals' env then begin
        (* we only add formals to global correspondance tables if some
           part of the kf is unchanged (otherwise, we can't reuse information
           about the formals anyways). Hence, we only add them into the local
           env for now. *)
        let env = add_locals formals formals' env in
        let env =
          { env with kernel_function = Kf.Map.add kf kf' env.kernel_function }
        in
        let same_spec = is_same_funspec kf.spec kf'.spec env in
        let same_body =
          match (Kf.has_definition kf, Kf.has_definition kf') with
          | false, false -> `Same_body
          | false, true | true, false -> `Body_changed
          | true, true ->
            is_same_fundec (Kf.get_definition kf) (Kf.get_definition kf') env
        in
        match same_spec, same_body with
        | false, `Body_changed -> `Not_present
        | false, `Callees_changed ->
          formals_correspondance formals formals';
          `Partial(kf',`Callees_spec_changed)
        | false, `Same_body ->
          formals_correspondance formals formals';
          `Partial(kf', `Spec_changed)
        | true, `Same_body ->
          formals_correspondance formals formals';
          `Same kf'
        | true, ((`Body_changed|`Callees_changed) as c) ->
          formals_correspondance formals formals';
          `Partial(kf', c)
      end else `Not_present
  in
  match Kf.Map.find_opt kf env.kernel_function with
  | Some kf' -> `Same kf'
  | None -> Kernel_function.memo add kf

and logic_info_correspondance ?loc li env =
  let add li =
    match find_candidate_logic_info ?loc li env with
    | None -> `Not_present
    | Some li' ->
      if is_same_list is_same_logic_var li.l_profile li'.l_profile env then
        begin
          let env = add_logic_prms li.l_profile li'.l_profile env in
          let env =
            { env with
              logic_info=Cil_datatype.Logic_info.Map.add li li' env.logic_info }
          in
          let res = is_same_logic_info li li' env in
          if res then begin
            logic_prms_correspondance li.l_profile li'.l_profile;
            `Same li'
          end else `Not_present
        end else `Not_present
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
