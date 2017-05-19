(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2016                                               *)
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
(*  for more details (enclosed in the file license/LGPLv2.1).             *)
(*                                                                        *)
(**************************************************************************)

open Cil_types
open Cil_datatype

(* ************************************************************************** *)
(** {Configuration} {{{ *)
(* ************************************************************************** *)

let current_stmt = ref Cil.dummyStmt

let generate = ref false
(* }}} *)

(* ************************************************************************** *)
(** {Types} {{{ *)
(* ************************************************************************** *)

(* Type of identifier tracked by a LHS referent number *)
type flow =
  | Direct (* take BlockID of RHS *)
  | Indirect (* take ReferentID of RHS *)
  | Copy (* Copy shadow from RHS to LHS *)
(* }}} *)

(* ************************************************************************** *)
(** {Miscellaneous} {{{ *)
(* ************************************************************************** *)

(* Generate a function name in the temporal analysis name space, i.e., prefixed
   by [__e_acsl_temporal_ + function name].
   NOTE: Further on, all analysis function names are used without prefix *)
let mk_api_name name =
  let fname = "temporal_" ^ name in Misc.mk_api_name fname

let is_alloc_name fn =
  fn = "malloc" || fn = "free" || fn = "realloc" || fn = "calloc"

let is_memcpy_name fn =
  fn = "memcpy"

let is_memset_name fn =
  fn = "memset"

let is_fn fname f =
  match fname with
  | { enode = Lval(Var(vi), _) } when f vi.vname -> true
  | _ -> false

let is_alloc fvi =
  is_fn fvi is_alloc_name

let is_memcpy fvi =
  is_fn fvi is_memcpy_name

let is_memset fvi =
  is_fn fvi is_memset_name

(* True if a named function has a definition and false otherwise *)
let has_fundef fname =
  let recognize fn =
    try
      let _ = Globals.Functions.find_def_by_name fn in true
    with
      Not_found -> false
  in is_fn fname recognize

(* Shortcuts for SA in Mmodel_analysis *)
let must_model_exp exp env =
  let kf, bhv = Extlib.the (Env.current_kf env), Env.get_behavior env in
    Mmodel_analysis.must_model_exp ~bhv ~kf exp

let must_model_lval lv env =
  let kf, bhv = Extlib.the (Env.current_kf env), Env.get_behavior env in
    Mmodel_analysis.must_model_lval ~bhv ~kf lv

let must_model_vi vi env =
  let kf, bhv = Extlib.the (Env.current_kf env), Env.get_behavior env in
    Mmodel_analysis.must_model_vi ~bhv ~kf vi

(* }}} *)

(*  ************************************************************************* *)
(** {Analysis function calls} {{{ *)
(* ************************************************************************** *)

(* Generate either
  - [store_nblock(lhs, rhs)], or
  - [store_nreferent(lhs, rhs)]
function call based on the value of [flow] *)
let mk_store_reference ~loc flow lhs rhs =
  let fname = match flow with
    | Direct -> "store_nblock"
    | Indirect -> "store_nreferent"
    | Copy -> failwith "Copy flow type in mk_store_reference"
  in
  Misc.mk_call ~loc (mk_api_name fname) [ Cil.mkAddrOf ~loc lhs; rhs ]

(* Generate a [save_*_parameter] call *)
let mk_save_param ~loc flow lhs pos =
  let infix = match flow with
    | Direct -> "nblock"
    | Indirect -> "nreferent"
    | Copy -> "copy"
  in
  let fname = "save_" ^ infix ^ "_parameter" in
  Misc.mk_call ~loc (mk_api_name fname) [ lhs ; Cil.integer ~loc pos ]

(* Generate [pull_parameter] call *)
let mk_pull_param ~loc vi pos =
  let exp = Cil.mkAddrOfVi vi in
  let fname = mk_api_name "pull_parameter" in
  let sz = Cil.kinteger ~loc IULong (Cil.bytesSizeOf vi.vtype) in
  Misc.mk_call ~loc fname [ exp ; Cil.integer ~loc pos ; sz  ]

(* Generate [(save|pull)_return(lhs, param_no)] call *)
let mk_handle_return_referent ?(save=true) ~loc lhs =
  let fname = match save with
    | true -> "save_return"
    | false -> "pull_return"
  in
  (* TODO: Returning structs is unsupported so far *)
  ignore(match (Cil.typeOf lhs) with
    | TPtr _  -> ()
    | _ -> failwith "Struct in return");
  Misc.mk_call ~loc (mk_api_name fname) [ lhs ]

(* Generate [reset_return()] call *)
let mk_reset_return_referent ~loc =
  Misc.mk_call ~loc (mk_api_name "reset_return") []

(* Generate [memcpy(lhs, rhs, size)] function call assuming that [lhs = rhs]
   represents an assignment of struct to a struct, that is, both sides are left
   values and we need to use addressof for both sides *)
let mk_temporal_memcpy_struct ~loc lhs rhs =
  let fname  = mk_api_name "memcpy" in
  let size = Cil.sizeOf ~loc (Cil.typeOfLval lhs) in
  let lhs = Cil.mkAddrOf ~loc lhs in
  Misc.mk_call ~loc fname [ lhs; rhs;  size ]
(* }}} *)

(* ************************************************************************** *)
(** {Handle assignments} {{{ *)
(* ************************************************************************** *)

(* Given an lvalue [lhs] representing LHS of an assignment, and an expression
  [rhs] representing its RHS compute addresses compute a triple (l,r,f), such
  that:
   - lval [l] and exp [r] are addresses of a pointer and a memory block, and
   - flow [f] indicates how to update the meta-data of [l] using information
    stored by [r]. The values of [f] indicate the following
     + Direct - referent number of [l] is assigned the referent number of [r]
     + Indirect - referent number of [l] is assigned the block number of [r]
     + Copy - metadata of [r] is copied to metadata of [l] *)
let rec assign_aux ?(ltype) lhs rhs loc =
  let ltype = match ltype with
    | Some l -> l
    | None -> (Cil.typeOfLval lhs)
  in
  match ltype with
  | TPtr _  ->
    let base, _ = Misc.ptr_index rhs in
    let rhs, flow =
      (match base.enode with
      | AddrOf _
      | StartOf _  -> rhs, Direct
      | Const _  -> base, Direct
      (* Unary operator describes !, ~ or -: treat it same as Const since
         it implies integer or logical operations. This case is rare but
         happens: for instance in Gap SPEC CPU benchmark the returned pointer
         is assigned -1 (for whatever bizarre reason) *)
      | UnOp _ -> base, Direct
      (* Special case for literal strings which E-ACSL rewrites into
         global variables: take the block number of a string *)
      | Lval(Var(vi), _) when Misc.is_generated_varinfo vi -> base, Direct
      (* Lvalue can be of different type than a pointer, for instance for
         the case when address is taken by value.
           uintptr_t addr = ...;
           char *p = (char* )addr;
         If this is the case then the analysis assumes that pointer is
         unavailable and takes the block number of address and the referent
         number of a pointer otherwise *)
      | Lval(lv) ->
        if Cil.isPointerType (Cil.typeOfLval  lv) then
          Cil.mkAddrOf ~loc lv, Indirect
        else
          rhs, Direct
      (* Binary operation which yields an integer (of FP) type.
         Since LHS is of pointer type we assume that the whole integer
         expression computes to an address for which there is no
         outer container, so the only thing to do is to take block number *)
      | BinOp(op, _, _, _) ->
        (* Make sure there are no be pointer operations here *)
        ignore((match op with
          | MinusPI | PlusPI | IndexPI -> assert false
          | _ -> ()));
        base, Direct
      | _ -> assert false)
    in Some (lhs, rhs, flow)
  | TNamed(info, _) ->
    assign_aux ~ltype:info.ttype lhs rhs loc
  | TInt _  | TFloat _  | TEnum _  -> None
  | TComp _   ->
    let rhs = (match rhs.enode with
    | AddrOf _  -> rhs
    | Lval(lv) -> Cil.mkAddrOf ~loc lv
    | _ -> assert false) in
    Some (lhs, rhs, Copy)
  (* va_list is a builtin type, we assume it has no pointers here and treat
     it as a "big" integer rather than a struct *)
  | TBuiltin_va_list _ -> None
  | TArray _ -> Some (lhs, rhs, Direct)
  (* void type should not happen as we are dealing with assignments *)
  | TVoid _ -> failwith "Void type in assignment"
  | TFun _ -> failwith "TFun type in assignment"

(* Generate a statement tracking temporal metadata associated with assignment
   [lhs] = [rhs], where lhs is a left value and [rhs] is an expression. *)
let mk_stmt_from_assign loc lhs rhs =
  match (assign_aux lhs rhs loc) with
  | Some (lhs, rhs, flow) ->
    let stmt = (match flow with
      | Direct | Indirect ->
        mk_store_reference ~loc flow lhs rhs
      | Copy ->
        mk_temporal_memcpy_struct ~loc lhs rhs)
    in Some stmt
  | None -> None
(* }}} *)

(* ************************************************************************** *)
(** {Handle Set instructions} {{{ *)
(* ************************************************************************** *)

(* Update local environment with a statement tracking temporal metadata
  associated with assignment [lhs] = [rhs] *)
let set_instr ?(post=false) loc lhs rhs fenv =
  let stmt = mk_stmt_from_assign loc lhs rhs in
  Extlib.may
    (fun stmt ->
      fenv := Env.add_stmt ~before:!current_stmt ~post !fenv stmt)
    stmt

(* Top-level handler for Set instructions *)
let set_instr ?(post=false) loc lhs rhs fenv =
  if must_model_lval lhs !fenv then
    set_instr ~post loc lhs rhs fenv

(* }}} *)

(* ************************************************************************** *)
(** {Handle Call instructions} {{{ *)
(* ************************************************************************** *)

(* Track function arguments: export referents of arguments to a global
   structure so they can be retrieved once that function is called *)
let save_params loc args fenv =
  List.iteri
    (fun index param ->
      let dummy_lv = Mem(param),NoOffset in
      let ltype = Cil.typeOf param in
      let vals = assign_aux ~ltype dummy_lv param loc in
      Extlib.may
        (fun (_, rhs, flow) ->
          if must_model_exp param !fenv then begin
            let stmt = mk_save_param ~loc flow rhs index in
            fenv := Env.add_stmt ~before:!current_stmt ~post:false !fenv stmt
          end)
        vals)
    args

(* Update local environment with a statement tracking temporal metadata
   associated with assignment [ret] = [func(args)]. *)
let call_with_ret ?(alloc=false) loc ret fenv =
  let rhs = Cil.new_exp ~loc (Lval(ret)) in
  let vals = assign_aux ret rhs loc in
  (* Track referent numbers of assignments via function calls *)
  Extlib.may
    (fun (lhs, rhs, flow) ->
      let flow, rhs = match flow with
        | Indirect when alloc -> Direct, (Misc.mk_deref ~loc rhs)
        | _ -> flow, rhs
      in
      let stmt =
        if alloc then
          mk_store_reference ~loc flow lhs rhs
        else
          mk_handle_return_referent ~save:false ~loc (Cil.mkAddrOf ~loc lhs)
      in
      fenv := Env.add_stmt ~before:!current_stmt ~post:true !fenv stmt)
    vals

(* Update local environment with a statement tracking temporal metadata
   associated with a memcpy call *)
let call_memcpy loc args fname fenv =
  if (is_memcpy fname) then begin
    let stmt = Misc.mk_call ~loc (mk_api_name "memcpy") args in
    fenv := Env.add_stmt ~before:!current_stmt ~post:false !fenv stmt;
  end

(* Update local environment with a statement tracking temporal metadata
   associated with a memset call. *)
let call_memset loc args fname fenv =
  if (is_memset fname) then begin
    let stmt = Misc.mk_call ~loc (mk_api_name "memset") args in
    fenv := Env.add_stmt ~before:!current_stmt ~post:false !fenv stmt;
  end

(* Top-level handler for Call instructions *)
let call_instr ret fname args loc fenv =
  (* Add function calls to reset_parameters and reset_return before each
     function call regardless. They are is not really required, as if the
     instrumentation is correct then the right parameters will be saved
     and the right parameter will be pulled at runtime. In practice, however,
     it makes sense to make this somewhat-debug-level-call. In production mode
     the implementation of the function should be empty and compiler should
     be able to optimize that code out. *)
  let stmt = Misc.mk_call ~loc (mk_api_name "reset_parameters") [] in
  fenv := Env.add_stmt ~before:!current_stmt ~post:false !fenv stmt;
  let stmt = mk_reset_return_referent ~loc in
  fenv := Env.add_stmt ~before:!current_stmt ~post:false !fenv stmt;
  (* Push parameters with either a call to a function pointer or a function
      definition otherwise there is no point. *)
  if Cil.isFunctionType (Cil.typeOf fname) || has_fundef fname then begin
    save_params loc args fenv
  end;
  (* Handle special cases of memcpy and memset *)
  call_memcpy loc args fname fenv;
  call_memset loc args fname fenv;
  let alloc = is_alloc fname || not (has_fundef fname) in
  Extlib.may
    (fun lhs ->
      if must_model_lval lhs !fenv then call_with_ret ~alloc loc lhs fenv)
    ret
(* }}} *)

(* ************************************************************************** *)
(** {Handle Local_init instructions} {{{ *)
(* ************************************************************************** *)
let rec handle_local_init_aux ?(offset=NoOffset) loc vi init fenv =
  match init with
  | SingleInit(exp) ->
    set_instr ~post:true loc (Var(vi), offset) exp fenv
  | CompoundInit(_, inits) ->
    List.iter
      (fun (off, init) ->
        let off = Cil.addOffset off offset in
        handle_local_init_aux ~offset:off loc vi init fenv)
      inits

let handle_local_init loc vi init fenv =
  handle_local_init_aux loc vi init fenv

let local_init_instr vi li loc fenv =
  match li with
  | AssignInit(init) ->
    handle_local_init loc vi init fenv
  | ConsInit(fname, args, _) ->
    let ret = Some (Var(vi), NoOffset) in
    let fname = Cil.evar ~loc fname in
    call_instr ret fname args loc fenv

(* Top-level handler for Local_init instructions *)
let local_init_instr vi li loc fenv =
  if must_model_vi vi !fenv then
    local_init_instr vi li loc fenv
(* }}} *)

(* ************************************************************************** *)
(** {Track function arguments} {{{ *)
(* ************************************************************************** *)

(* Update local environment with a statement tracking temporal metadata
   associated with adding a function argument to a stack frame *)
let rec track_argument ?(typ) param index env =
  let typ = Extlib.opt_conv param.vtype typ in
  match typ with
  | TPtr _
  | TComp _ ->
    let stmt = mk_pull_param ~loc:Location.unknown param index in
    Env.add_stmt ~post:false env stmt
  | TInt _ | TFloat _ | TEnum _ | TBuiltin_va_list _ -> env
  | TNamed(info, _) ->
    track_argument ~typ:info.ttype param index env
  | _ -> failwith "Failed to handle function parameter"
(* }}} *)

(* ************************************************************************** *)
(** {Handle return statements} {{{ *)
(* ************************************************************************** *)

(* Update local environment [fenv] with statements tracking return value
   of a function. *)
let handle_return_stmt loc ret fenv =
  match ret.enode with
  | Lval(lv) ->
    if Cil.isPointerType (Cil.typeOfLval lv) then begin
      let exp = Cil.mkAddrOf ~loc lv in
      let stmt = mk_handle_return_referent ~loc ~save:true exp in
      fenv := Env.add_stmt ~post:false !fenv stmt
    end
  | _ -> failwith "Something other than Lval in return"

let handle_return_stmt loc ret fenv =
  if must_model_exp ret !fenv then
    handle_return_stmt loc ret fenv

(* ************************************************************************** *)
(** {Handle instructions} {{{ *)
(* ************************************************************************** *)

(* Update local environment [fenv] with statements tracking
   instruction [instr] *)
let handle_instruction instr fenv =
  match instr with
  | Set(lv, exp, loc) ->
    set_instr loc lv exp fenv
  | Call(ret, fname, args, loc) ->
    call_instr ret fname args loc fenv
  | Local_init(vi, li, loc) ->
    local_init_instr vi li loc fenv
  | Asm _ | Skip _ -> ()
  | Code_annot _ -> failwith "Code_annot is not supported"


(* ************************************************************************** *)
(** {Initialization of globals} {{{ *)
(* ************************************************************************** *)
(* Provided that [vi] is a global variable initialized by the initializer [init]
   at offset [off] return [Some stmt], where [stmt] is a statement
   tracking that initialization. If [init] does not need to be tracked than
   the return value is [None] *)
let mk_global_init vi off init env =
  let exp = match init with
    | SingleInit(e) -> e
    (* Compound initializers should have been thrown away at this point *)
    | _ -> failwith "Unexpected ComppoundInit in global initializer"
  in
  (* Initializer expression can be a literal string, so look up the
     corresponding variable which that literal string has been converted to *)
  let exp = (try
    let rec get_string e = match e.enode with
      | Const(CStr str) -> str
      | CastE(_, exp) -> get_string exp
      | _ -> raise Not_found
    in
    let str = get_string exp in
    Cil.evar ~loc:Location.unknown (Literal_strings.find str)
  with
    (* Not a literal string: just use the expression at hand *)
    Not_found -> exp)
  in
  (* The input [vi] is from the old project, so get the corresponding variable
     from the new one, otherwise AST integrity is violated *)
  let vi = Cil.get_varinfo (Env.get_behavior env) vi in
  let lv = (Var(vi), off) in
  mk_stmt_from_assign Location.unknown lv exp

(* ************************************************************************** *)
(** {Public API} {{{ *)
(* ************************************************************************** *)

let enable param =
  generate := param

let is_enabled () =
  !generate

let handle_arguments kf env =
  if is_enabled () then
    let getpar = Cil.get_varinfo (Env.get_behavior env) in
    let formals = List.map getpar (Kernel_function.get_formals kf) in
    let env, _ = List.fold_left
      (fun (env, index) param ->
        if Mmodel_analysis.must_model_vi ~kf param then
          track_argument param index env, index + 1
        else
          env, index + 1)
      (env, 0)
      formals
    in env
  else
    env

let handle_stmt stmt env =
  if is_enabled () then begin
    current_stmt := stmt;
    let fenv = ref env in
    (match stmt.skind with
    | Instr(instr) ->
      handle_instruction instr fenv
    | Return(ret, loc) ->
      Extlib.may (fun ret -> handle_return_stmt loc ret fenv) ret
    | _ -> ());
    current_stmt := Cil.dummyStmt;
    !fenv
  end else
    env

let handle_global_init vi off init env =
  if is_enabled () then
    mk_global_init vi off init env
  else
    None

(* }}} *)
