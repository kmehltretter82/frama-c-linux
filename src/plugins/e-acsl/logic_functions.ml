(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2018                                               *)
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

type lfsig_info = { (* Logic Function SIGnature INFOrmation *)
  lfs_li: logic_info; (* the logic definition,
                         base template to be specialized *)
  lfs_args_lty: logic_type list; (* types of the args for the specialization *)
  lfs_lty: logic_type (* return type for the specialization *)
}

(**************************************************************************)
(********************** Forward references ********************************)
(**************************************************************************)

let predicate_to_exp_ref
  : (kernel_function -> Env.t -> predicate -> exp * Env.t) ref
  = Extlib.mk_fun "named_predicate_to_exp_ref"

let term_to_exp_ref
  : (kernel_function -> Env.t -> term -> exp * Env.t) ref
  = Extlib.mk_fun "term_to_exp_ref"

let add_cast_ref
  : (location -> Env.t -> typ option -> bool -> exp -> exp * Env.t) ref
  = Extlib.mk_fun "add_cast_ref"

(*****************************************************************************)
(****************** Generation of function bodies ****************************)
(*****************************************************************************)

(* Determine the C typ corresponding to a formal argument based on its logic
  type. In particular, [arg_typ_from_lty] MUST NOT return arrays:
  they should be converted into pointers. *)
let arg_typ_from_lty lty = match lty with
  | Linteger ->
    Gmpz.t_ptr () (* but not [Gmpz.t] as returned by [Typing.typ_of_lty] *)
  | Lreal ->
    Error.not_yet "[arg_typ_from_lty] reals" (* TODO: handle in MR !226 *)
  | Ctype _ | Ltype _ | Lvar _ | Larrow _ ->
    let typ = Typing.typ_of_lty lty in
    if Cil.isArrayType typ then Error.not_yet "[arg_typ_from_lty] array"
    else typ

(* Creates a new [kf] with an empty body. Its body is to be filled
  through [fill_kf] afterwards. These two operations are purposefully
  made distinct in order to avoid non-termination in case of recursive
  definitions. *)
let empty_kf lfs typ =
  let li = lfs.lfs_li in
  let fname = Functions.RTL.mk_gen_name
    (Env.Varname.get ~scope:Env.Global li.l_var_info.lv_name)
  in
  let is_not_returnable = Cil.isArrayType typ in
  let ty_f = if is_not_returnable then Cil.voidType else typ in
  let vi_f = Cil.makeGlobalVar
    fname
    (TFun
      (ty_f,
      None, (* Typs of the arguments. Will be updated in the following
               through [Cil.makeFormalVar] *)
      false,
      li.l_var_info.lv_attr))
  in
  let fundec =
    { svar = vi_f;
      sformals = []; (* Will be updated in the following
                        through [Cil.makeFormalVar] *)
      slocals = []; (* Will be updated by [fill_kf] *)
      smaxid = 0;
      sbody = Cil.mkBlock []; (* Will be updated by [fill_kf] *)
      smaxstmtid = None;
      sallstmts = [];
      sspec =  Cil.empty_funspec () }
  in
  (* Now updating information on arguments *)
  List.iter2
    (fun lv lty ->
      let name = Functions.RTL.mk_gen_name lv.lv_name ^ "_arg" in
      let typ = arg_typ_from_lty lty in
      ignore (Cil.makeFormalVar fundec ~where:"$" name typ))
    li.l_profile
    lfs.lfs_args_lty;
  if is_not_returnable then
    (* If the result of the function cannot be returned,
      then define it as being the (additional) first argument *)
    ignore (Cil.makeFormalVar
      fundec
      ~where:"^"
      "__retres_arg"
      (arg_typ_from_lty (Extlib.the li.l_type)));
  (* Creating and returning the kf *)
  { fundec = Definition(fundec, Cil_datatype.Location.unknown);
    spec = Cil.empty_funspec () }

(* Bind arguments to the intervals corresponding to their logic type. *)
let add_interv_bindings lfs =
  List.iter2
    (fun lv lty ->
      match lty with
      | Linteger ->
        let i = Ival.inject_range None None in
        Interval.Env.add lv i
      | Ctype (TFloat _) -> (* TODO: handle in MR !226 *)
        ()
      | Lreal ->
        Error.not_yet "real numbers"
      | Ctype (TInt(ik, _)) ->
        let i = Interval.interv_of_typ (TInt(ik, [])) in
        Interval.Env.add lv i
      | Ctype _ ->
        ()
      | Ltype _ | Lvar _ | Larrow _ ->
        Options.fatal "unexpected logic type")
    lfs.lfs_li.l_profile
    lfs.lfs_args_lty

let remove_interv_bindings lfs =
  List.iter
    (fun lv -> Interval.Env.remove lv)
    lfs.lfs_li.l_profile

let retype lfs = match lfs.lfs_li.l_body with
  | LBpred p ->
    Typing.clear_all_pred_or_term (Misc.PoT_pred p);
    Typing.type_named_predicate ~must_clear:false p
  | LBterm t ->
    Typing.clear_all_pred_or_term (Misc.PoT_term t);
    Typing.type_term ~use_gmp_opt:true t
  | LBnone ->
    Error.not_yet "logic functions with no definition nor reads clause"
  | LBreads _ ->
    Error.not_yet "logic functions performing read accesses"
  | LBinductive _ ->
    Error.not_yet "logic functions inductively defined"

(* Bind lv to C variables.
  Case A: lv can be directly binded to the formal arg fo the C function.
          Example: the typ corresponding to lv is [int]
  Case B: lv CANNOT be directly binded to the formal arg.
          This is notably the case for GMP since if they were directly binded,
          then the function would free them before returning. Thus copies are
          required. *)
let add_varinfo_bindings ~loc kf env lfs =
  (* Handle typs that cannot be returned *)
  let vi_args =
    let fundec = Misc.fundec_of_kf kf in
    let vi_ty = match fundec.svar.vtype with
      | TFun(ty, _, _, _) -> ty
      | _ -> assert false
    in
    if Cil_datatype.Typ.equal Cil.voidType vi_ty then
      match fundec.sformals with
      | [] -> assert false
      | _ :: vi_args -> vi_args (* First arg is the result *)
    else
      fundec.sformals
  in
  let env =
    let lvs_and_ltys =
      List.map2 (fun lv lty -> lv, lty) lfs.lfs_li.l_profile lfs.lfs_args_lty
    in
    List.fold_left2
      (fun env (lv, lty) vi_arg ->
        match Typing.ty_of_logic_ty lty with
        | Typing.C_type _ | Typing.Other ->
          (* Case A *)
          Env.Logic_binding.add_binding env lv vi_arg
        | Typing.Gmp ->
          (* Case B *)
          let ty = Typing.typ_of_lty lv.lv_type in
          let vi, _, env = Env.Logic_binding.add ~ty env lv in
          vi_arg.vtype <- Gmpz.t ();
          let stmt = Gmpz.init_set
            ~loc (Cil.var vi) (Cil.evar ~loc vi) (Cil.evar ~loc vi_arg)
          in
          vi_arg.vtype <- Gmpz.t_ptr ();
          let env = Env.add_stmt env stmt in
          env)
      env
      lvs_and_ltys
      vi_args
  in
  env

(* Generate the function's body. For predicates. *)
let pred_to_block ~loc kf env p =
  (* Translate *)
  let named_predicate_to_exp = !predicate_to_exp_ref in
  let e, env = named_predicate_to_exp kf env p in
  (* Create the variable [retres] to be returned,
    the stmt [set_retres] setting it,
    and the stmt [return_retres] returning it. *)
  let fundec = Misc.fundec_of_kf kf in
  let retres = Cil.makeLocalVar fundec "__retres" Cil.intType in
  let set_retres =
    Cil.mkStmtOneInstr ~valid_sid:true (Set (Cil.var retres, e, loc))
  in
  let return_retres = Cil.mkStmt
    ~valid_sid:true (Return (Some (Cil.evar ~loc retres), loc))
  in
  (* The whole block *)
  let b, env =
    Env.pop_and_get env set_retres ~global_clear:false Env.Middle
  in
  b.blocals <- retres :: b.blocals;
  b.bstmts <- b.bstmts @ [ return_retres ];
  b.bscoping <- true; (* Kernel details *)
  b, env

(* Generate the function's body. For terms. *)
let term_to_block ~loc kf env t lty (* the return type *) =
  let term_to_exp = !term_to_exp_ref in
  let e, env = term_to_exp kf env t in
  (* Functions that are of primitive types are not retyped
     ==> cast needed in case the type system inferred a different type *)
  let ctx = Typing.typ_of_lty lty in
  let add_cast = !add_cast_ref in
  let e, env = add_cast loc env (Some ctx) false e in
  (* The body itself *)
  let fundec = Misc.fundec_of_kf kf in
  begin match Typing.ty_of_logic_ty lty with
  | Typing.C_type _ | Typing.Other ->
    let typ = Typing.get_typ t in
    assert (not (Cil_datatype.Typ.equal Cil.voidType typ));
    (* Create the variable [retres] to be returned,
      the stmt [set_retres] setting it,
      and the stmt [return_retres] returning it. *)
    let retres = Cil.makeLocalVar fundec "__retres" typ in
    let set_retres =
    Cil.mkStmtOneInstr ~valid_sid:true (Set (Cil.var retres, e, loc))
    in
    let return_retres = Cil.mkStmt
      ~valid_sid:true (Return (Some (Cil.evar ~loc retres), loc))
    in
    (* The whole block *)
    let b, env =
      Env.pop_and_get env set_retres ~global_clear:false Env.Middle
    in
    b.blocals <- retres :: b.blocals;
    b.bstmts <- b.bstmts @ [ return_retres ];
    b.bscoping <- true; (* Kernel details *)
    b, env
  | Typing.Gmp ->
    (* GMPs are not returned but given as (additional) first argument
      to the function. *)
    let set_first_arg =
      let first_arg = List.hd fundec.sformals in
      Misc.mk_call
        (* We cannot call [Gmpz.set] since it will only make an alias *)
        ~loc "__gmpz_init_set" [ Cil.evar ~loc first_arg; e ]
    in
    let return_void = Cil.mkStmt ~valid_sid:true (Return (None, loc)) in
    (* The whole block *)
    let b, env =
      Env.pop_and_get env set_first_arg ~global_clear:false Env.Middle
    in
    b.bstmts <- b.bstmts @ [ return_void ];
    b.bscoping <- true; (* Kernel details *)
    b, env
  end

(* Fill [kf]'s body based on [lfs]. See also: [empty_kf]. *)
let fill_kf lfs kf =
  (* Init env *)
  let env = Env.push Env.dummy in
  Env.set_current_kf env kf;
  let loc = Cil_datatype.Location.unknown in
  let env = add_varinfo_bindings ~loc kf env lfs in
  (* Create kf's body (the fundec's block) *)
  let b, env = match lfs.lfs_li.l_body with
    | LBpred p ->
      pred_to_block ~loc kf env p
    | LBterm t ->
      term_to_block ~loc kf env t lfs.lfs_lty
    | LBnone ->
      Error.not_yet "logic functions with no definition nor reads clause"
    | LBreads _ ->
      Error.not_yet "logic functions performing read accesses"
    | LBinductive _ ->
      Error.not_yet "logic functions inductively defined"
  in
  (* Fill the fundec *)
  let fundec = Misc.fundec_of_kf kf in
  fundec.sbody <- b;
  let new_vars =
    List.map (fun (vi, _) -> vi) (Env.get_generated_variables env)
  in
  fundec.slocals <- fundec.slocals @ new_vars

(**************************************************************************)
(***************************** Memoization ********************************)
(**************************************************************************)

module Memo = Hashtbl.Make(struct
  type t = lfsig_info
  let equal lfs1 lfs2 =
    Cil_datatype.Logic_info.equal lfs1.lfs_li lfs2.lfs_li &&
    List.fold_left2
      (fun b lty1 lty2 -> b && Cil_datatype.Logic_type.equal lty1 lty2)
      true
      lfs1.lfs_args_lty
      lfs2.lfs_args_lty
  let hash = Hashtbl.hash
end)

let tbl = Memo.create 7

let memo lfs typ =
  try Memo.find tbl lfs
  with Not_found ->
    (* We need to create a new [kf]. It is done as follows:
        Step 1: Create a [kf] with an empty body
        Step 2: Memoize it
        Step 3: Fill it
      In particular, its body CANNOT be filled during its creation: it would
      lead to non-termination for recursive definitions. *)
    (* Step 1 *)
    let kf = empty_kf lfs typ in
    (* Step 2 *)
    Memo.add tbl lfs kf;
    (* Step 3 *)
    fill_kf lfs kf;
    (* Kernel details *)
    let fundec = Misc.fundec_of_kf kf in
    fundec.svar.vdefined <- true;
    Globals.Functions.register kf;
    (* Return *)
    kf

(* Returns all the [kf] that have been constructed and memoized
  so far for the given [logic_info]. *)
let find_kfs li =
  Memo.fold
    (fun lfs kf l ->
      if Cil_datatype.Logic_info.equal lfs.lfs_li li then kf :: l
      else l)
    tbl
    []

(*****************************************************************************)
(****************** Generation of function calls *****************************)
(*****************************************************************************)

let generate ~loc env t li args args_lty =
  let name = li.l_var_info.lv_name ^ "_tapp" in
  let mk_call vi =
    (* Building the arguments 1/3:
      If the result is an array (eg gmp), then it cannot be returned.
      Thus we let it be the (additional) first argument. *)
    let vi_f_typ = Typing.get_typ t in
    let args, lvl_opt =
      if Cil.isArrayType vi_f_typ then
        (Cil.evar ~loc vi) :: args, None
      else
        args, Some (Cil.var vi)
    in
    (* Building the arguments 2/3:
      AST sanity: arrays that are given as arguments of functions
                  must be explicitely indicated as being pointers *)
    let args = List.map
      (fun arg ->
        if Cil_datatype.Typ.equal (Cil.typeOf arg) (Gmpz.t ()) then
          (* TODO: real numbers *)
          Cil.mkCast ~force:true ~e:arg ~newt:(Gmpz.t_ptr ())
        else
          arg)
      args
    in
    (* Building the arguments 3/3:
      E-ACSL typing: short and other integer types less than in
                     are cast into int *)
    let args = List.map
      (fun arg ->
        match Cil.typeOf arg with
        | TInt(kind, _) ->
          if Cil.intTypeIncluded kind IInt then
            Cil.mkCast ~force:false ~e:arg ~newt:Cil.intType
          else
            arg
        | TVoid _ | TFloat _ | TPtr _ | TArray _ | TFun _ | TNamed _
        | TComp _ |TEnum _ | TBuiltin_va_list _ ->
          arg)
      args
    in
    let lty = match Typing.get_integer_ty t with
      | Typing.Gmp -> Linteger
      | Typing.C_type ik -> Ctype (TInt (ik, []))
      | Typing.Other -> t.term_type
    in
    let lfs = {
        lfs_li = li;
        lfs_lty = lty;
        lfs_args_lty = args_lty;
      }
    in
    (* Memoization. We MUST guarantee that interval and type bindings
      for logic vars, terms and predicates from the logic definition of
      the function are restored after memoization. *)
    add_interv_bindings lfs;
    retype lfs;
    let kf = memo lfs vi_f_typ in
    remove_interv_bindings lfs;
    retype lfs;
    (* The call stmt *)
    let fundec = Misc.fundec_of_kf kf in
    let vi_f = fundec.svar in
    Cil.mkStmtOneInstr
      (Call (
        lvl_opt,
        (Cil.evar vi_f),
        args,
        loc))
  in
  match Typing.get_integer_ty t with
  | Typing.C_type _ | Typing.Other ->
    let res = Env.new_var
      ~loc
      ~name
      env
      (Some t)
      (Typing.get_typ t)
      (fun vi_app _ -> [ mk_call vi_app ])
    in
    res
  | Typing.Gmp ->
    Env.new_var_and_mpz_init
      ~loc
      ~name
      env
      (Some t)
      (fun vi_app _ -> [ mk_call vi_app ])

(**************************************************************************)
(******************************** Visitor *********************************)
(**************************************************************************)

(* TODO: Or is it better to directly use E-ACSL's main visitor in [Visit]?
  The decision should take into account the fact that [Visit] is already
  very big. *)

let lfunctions_visitor = object (self)
  inherit Visitor.frama_c_inplace
  val mutable new_definitions: global list = []
  method private insert_lfunctions l = l @ new_definitions
  method !vglob_aux = function
    | GAnnot(ga, _) as g ->
      Cil.DoChildrenPost
      (fun _ -> match ga with
        | Dfun_or_pred(li, _) ->
          begin match li.l_labels with
          | [] ->
            (* Case of logic definitions WITHOUT labels. *)
            let kfs = find_kfs li in
            let loc = Cil_datatype.Location.unknown in
            let new_decls = List.map
              (fun kf ->
                let fundec = Misc.fundec_of_kf kf in
                let new_g = GFun(fundec, loc) in
                new_definitions <- new_g :: new_definitions;
                GFunDecl(Cil.empty_funspec (), fundec.svar, loc))
              kfs
            in
            g :: new_decls
          | _ :: _ ->
            (* Case of logic definitions WITH labels. Not yet supported for
            the time being. Just let it go here: an exception will be raised
            in [Translate]. *)
            [g]
          end
        | Dvolatile _ | Daxiomatic _ | Dtype _ | Dlemma _ | Dinvariant _
        | Dtype_annot _ | Dmodel_annot _ | Dcustom_annot _ | Dextended _ ->
          [g])
    | GType _ | GCompTag _ | GCompTagDecl _ | GEnumTag _ | GEnumTagDecl _
    | GVarDecl _ | GFunDecl _ | GVar _ | GFun _ | GAsm _ | GPragma _
    | GText _ ->
      Cil.DoChildren
  method !vfile _ =
    Cil.DoChildrenPost
      (fun file ->
        file.globals <- self#insert_lfunctions file.globals;
        file)
end

let do_visit f = Visitor.visitFramacFile lfunctions_visitor f
