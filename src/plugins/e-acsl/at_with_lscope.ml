(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2018                                               *)
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

(**************************************************************************)
(********************** Forward references ********************************)
(**************************************************************************)

let predicate_to_exp_ref
    : (kernel_function -> Env.t -> predicate -> exp * Env.t) ref
    = Extlib.mk_fun "named_predicate_to_exp_ref"

let term_to_exp_ref
    : (kernel_function -> Env.t -> term -> exp * Env.t) ref
    = Extlib.mk_fun "term_to_exp_ref"

(*****************************************************************************)
(**************************** Handling memory ********************************)
(*****************************************************************************)

module H_malloc_free = Cil_datatype.Fundec.Hashtbl

type malloc_and_free_stmts = {
  mf_malloc : stmt;
  mf_free : stmt
}

let tbl_malloc_free : (stmt list * stmt list) H_malloc_free.t =
  (* The first (resp.second) list is for malloc (resp. free) stmts *)
  H_malloc_free.create 7

let add_malloc_and_free_stmts kf mf =
  match kf.fundec with
  | Definition(fundec, _) ->
    begin try
      let malloc_stmts, free_stmts =
        H_malloc_free.find tbl_malloc_free fundec
      in
      H_malloc_free.replace
        tbl_malloc_free
        fundec
        (mf.mf_malloc :: malloc_stmts, mf.mf_free :: free_stmts)
    with Not_found ->
      H_malloc_free.add tbl_malloc_free fundec  ([mf.mf_malloc], [mf.mf_free])
    end
  | Declaration _ ->
    assert false

let get_malloc_and_free_stmts fundec =
  try H_malloc_free.find tbl_malloc_free fundec
  with Not_found -> [], []

(**************************************************************************)
(*************************** Translation **********************************)
(**************************************************************************)

(* Make Lvs_quantif(tmin, lv, tmax) correspond to (t_size, t_shifted)
  where t_size = tmax - tmin + 1 (+1 because the inequalities are large
                                  due to previous normalization)
  and t_shifted = lv - tmin (so that we start indexing at 0) *)
let rec memory_infos_from_quantifs ~loc kf env lscope res =
  match Lscope.top lscope with
  | None ->
    res, env
  | Some(lscope_var, lscope') ->
    match lscope_var with
    | Lscope.Lvs_quantif(tmin, _, tmax)
      when (Misc.term_has_lv_from_vi tmin)
        || (Misc.term_has_lv_from_vi tmax) ->
      Error.not_yet "\\at with logic variable linked to C variable"
    | Lscope.Lvs_quantif(tmin, lv, tmax) ->
      let t_size = Logic_const.term
        ~loc (TBinOp(MinusA, tmax, tmin)) Linteger
      in
      let t_size = Logic_const.term
        ~loc (TBinOp(PlusA, t_size, Cil.lone ~loc ())) Linteger
      in
      let i = Interval.infer t_size in
      (* The amount of memory we allocate depends on the precision of
        the interval inference. We need to do this over-approximation
        because the bounds [tmax] and [tmin] can be terms that are so complex
        that we cannot precisely determine the precise value of [t_size] *)
      let t_size = match Ival.min_and_max i with
      | Some _, Some max ->
        Logic_const.tint ~loc max
      | _ ->
        Error.not_yet
          ("\\at on purely logical variables and with quantifier that uses " ^
            "too complex bound " ^
            "(E-ACSL cannot infer a finite upper bound to it)")
      in
      (* Index *)
      let t_lv = Logic_const.tvar ~loc lv in
      let t_shifted = Logic_const.term
        ~loc (TBinOp(MinusA, t_lv, tmin)) Linteger
      in
      (* Returning *)
      let res = (t_size, t_shifted) :: res in
      memory_infos_from_quantifs ~loc kf env lscope' res
    | Lscope.Lvs_let(_, t) | Lscope.Lvs_global(_, t)
      when (Misc.term_has_lv_from_vi t) ->
      Error.not_yet "\\at with logic variable linked to C variable"
    | Lscope.Lvs_let _ ->
      memory_infos_from_quantifs ~loc kf env lscope' res
    | Lscope.Lvs_formal _ ->
      Error.not_yet "\\at using formal variable of a logic function"
    | Lscope.Lvs_global _ ->
      Error.not_yet "\\at using global logic variable"

let size_from_memory_infos ~loc memory_infos =
  List.fold_left
    (fun t_size (t_s, _) ->
      Logic_const.term ~loc (TBinOp(Mult, t_size, t_s)) Linteger)
    (Cil.lone ~loc ())
    memory_infos

(* [mk_storing_loops] creates the nested loops that are used to store the
  different possible values of [pot].
  These loops are similar to those generated by [Quantif], with the difference
  that the aim of the innermost block is to store values,
  not to check the validity of some (quantified) predicate. *)
let rec mk_storing_loops ~loc kf env lscope lval pot =
  let term_to_exp = !term_to_exp_ref in
  let named_predicate_to_exp = !predicate_to_exp_ref in
  match Lscope.top lscope with
  | None ->
    begin match pot with
    | Misc.PoT_pred p ->
      let e, env = named_predicate_to_exp kf (Env.push env) p in
      let storing_stmt =
        Cil.mkStmtOneInstr ~valid_sid:true (Set(lval, e, loc))
      in
      let block, env = Env.pop_and_get
        env storing_stmt ~global_clear:true Env.After
      in
      block, env
    | Misc.PoT_term t ->
      begin match Typing.get_integer_ty t with
      | Typing.C_type _ | Typing.Other ->
        let e, env = term_to_exp kf (Env.push env) t in
        let storing_stmt =
          Cil.mkStmtOneInstr ~valid_sid:true (Set(lval, e, loc))
        in
        let block, env = Env.pop_and_get
          env storing_stmt ~global_clear:true Env.After
        in
        block, env
      | Typing.Gmp ->
        Error.not_yet "\\at on purely logical variables and over gmp type"
      end
    end
  | Some(Lscope.Lvs_quantif(tmin, lv, tmax), lscope') ->
    (* TODO: a refactor with [Quantif] may be possible for this case *)
    let vi_of_lv = Env.Logic_binding.get env lv in
    let env = Env.push env in
    let vi_of_lv, _, env =
      (* We need to redeclare the lv thus new varinfo needed *)
      Env.Logic_binding.add ~ty:vi_of_lv.vtype env lv
    in
    let t_lv = Logic_const.tvar ~loc lv in
    (* Guard *)
    let guard = Logic_const.term
      ~loc
      (TBinOp(Le, t_lv, tmax))
      (Ctype Cil.intType)
    in
    Typing.type_term ~use_gmp_opt:false ~ctx:Typing.c_int guard;
    let guard_exp, env = term_to_exp kf env guard in
    (* Break *)
    let break_stmt = Cil.mkStmt ~valid_sid:true (Break guard_exp.eloc) in
    (* Inner loop *)
    let loop', env = mk_storing_loops ~loc kf env lscope' lval pot in
    let loop' = Cil.mkStmt ~valid_sid:true (Block loop') in
    (* Loop counter *)
    let plus_one_term = Logic_const.term
      ~loc
      (TBinOp(PlusA, t_lv, Cil.lone ~loc ()))
      Linteger
    in
    Typing.type_term ~use_gmp_opt:true plus_one_term;
    let plus_one_exp, env = term_to_exp kf env plus_one_term in
    let plus_one_stmt = match Typing.get_integer_ty plus_one_term with
      | Typing.C_type _ | Typing.Gmp->
        Gmpz.init_set ~loc (Cil.var vi_of_lv) (Cil.evar vi_of_lv) plus_one_exp
      | Typing.Other ->
        assert false
    in
    (* If guard is satisfiable then inner loop, else break *)
    let if_stmt = Cil.mkStmt
      ~valid_sid:true
      (If(guard_exp,
        Cil.mkBlock [loop'; plus_one_stmt],
        Cil.mkBlock [ break_stmt ],
        guard_exp.eloc))
    in
    let loop = Cil.mkStmt
      ~valid_sid:true
      (Loop ([],
        Cil.mkBlock [ if_stmt ],
        loc,
        None,
        Some break_stmt))
    in
    (* Init lv *)
    let tmin_exp, env = term_to_exp kf env tmin in
    let set_tmin = match Typing.get_integer_ty plus_one_term with
      | Typing.C_type _ | Typing.Gmp->
        Gmpz.init_set ~loc (Cil.var vi_of_lv) (Cil.evar vi_of_lv) tmin_exp
      | Typing.Other ->
        assert false
    in
    (* The whole block *)
    let block' = Cil.mkBlock [set_tmin; loop] in
    let block'_stmt = Cil.mkStmt ~valid_sid:true (Block block') in
    let block, env = Env.pop_and_get
      env block'_stmt ~global_clear:true Env.After
    in
    block, env
  | Some(Lscope.Lvs_let(lv, t), lscope') ->
    let vi_of_lv = Env.Logic_binding.get env lv in
    let env = Env.push env in
    let vi_of_lv, exp_of_lv, env =
     (* We need to redeclare the lv thus new varinfo needed *)
      Env.Logic_binding.add ~ty:vi_of_lv.vtype env lv
    in
    let e, env = term_to_exp kf env t in
    let let_stmt = Gmpz.init_set
      ~loc (Cil.var vi_of_lv) exp_of_lv  e
    in
    let block', env = mk_storing_loops ~loc kf env lscope' lval pot in
    (* The whole block *)
    block'.bstmts <- let_stmt :: block'.bstmts;
    let block'_stmt = Cil.mkStmt ~valid_sid:true (Block block') in
    let block, env = Env.pop_and_get
      env block'_stmt ~global_clear:true Env.After
    in
    block, env
  | Some(Lscope.Lvs_formal _, _) ->
    Error.not_yet "\\at using formal variable of a logic function"
  | Some(Lscope.Lvs_global _, _) ->
    Error.not_yet "\\at using global logic variable"

(* Associate to each possible tuple of quantifiers
  a unique index from the set {n | 0 <= n < n_max}.
  That index will serve to identify the memory location where the evaluation
  of the term/predicate is stored for the given tuple of quantifier.
  The following gives the smallest set of such indexes (hence we use the
  smallest amount of memory in some respect):
  To (t_shifted_n, t_shifted_n-1, ..., t_shifted_1)
  where 0 <= t_shifted_i < beta_i
  corresponds:
    sum_from_i_eq_1_to_n(
      t_shifted_i *
      mult_from_j_eq_1_to_i-1(beta_j)
    ) *)
let rec index_from_mem_infos ~loc memory_infos =
  match memory_infos with
  | [] ->
    Cil.lzero ~loc ()
  | [(_, t_shifted)] ->
    t_shifted
  | (_, t_shifted) :: memory_infos' ->
    let index' = index_from_mem_infos ~loc memory_infos' in
    let bi = t_shifted in
    let rec pi_beta_j memory_infos = match memory_infos with
      | [] ->
        Cil.lone ~loc ()
      | (t_size, _) :: memory_infos' ->
        let pi_beta_j' = pi_beta_j memory_infos' in
        Logic_const.term ~loc (TBinOp(Mult, t_size, pi_beta_j')) Linteger
    in
    let pi_beta_j = pi_beta_j memory_infos' in
    let bi_mult_pi_beta_j = Logic_const.term ~loc
      (TBinOp(Mult, bi, pi_beta_j)) Linteger
    in
    Logic_const.term ~loc (TBinOp(PlusA, bi_mult_pi_beta_j, index')) Linteger

let put_block_at_label env block label =
  let stmt = Label.get_stmt (Env.get_visitor env) label in
  let env_ref = ref env in
  let o = object
    inherit Visitor.frama_c_inplace
    method !vstmt_aux stmt =
      assert (!env_ref == env);
      let pre = match label with
        (* This was just shamelessly copied from [at_to_exp],
          with no much understanding... *)
        | BuiltinLabel(Here | Post) -> true
        | BuiltinLabel(Old | Pre | LoopEntry | LoopCurrent | Init)
        | FormalLabel _ | StmtLabel _ -> false
      in
      env_ref := Env.extend_stmt_in_place env stmt ~pre block;
      Cil.ChangeTo stmt
  end
  in
  let bhv = Env.get_behavior env in
  ignore( Visitor.visitFramacStmt o (Cil.get_stmt bhv stmt));
  !env_ref

let to_exp ~loc kf env pot label =
  if not(Options.Full_mmodel.get ()) then
    Error.not_yet
      "\\at on purely logical variables but without full memory model";
  if Options.Gmp_only.get () then
    Error.not_yet "\\at on purely logical variables and with gmp only";
  let term_to_exp = !term_to_exp_ref in
  let memory_infos, env =
    memory_infos_from_quantifs ~loc kf env (Env.get_lscope env) []
  in
  (* Creating the pointer *)
  let ty = match pot with
  | Misc.PoT_pred _ ->
    Cil.intType
  | Misc.PoT_term t ->
    begin match Typing.get_integer_ty t with
    | Typing.C_type _ | Typing.Other ->
      Typing.get_typ t
    | Typing.Gmp ->
      Error.not_yet "\\at on purely logical variables and over gmp type"
    end
  in
  let ty_ptr = TPtr(ty, []) in
  let name =
    Env.Varname.get ~scope:Env.Global "at"
    (* the scope is actually [Function], but we use [Global] here to trick
      [Env.Varname.get] so that it produces distinct names *)
  in
  let vi_at, at_e, env = Env.new_var
    ~loc
    ~name
    ~scope:Env.Function
    env
    None
    ty_ptr
    (fun _ _ -> [])
  in
  (* Size *)
  let lty_sizeof = Ctype Cil.(theMachine.typeOfSizeOf) in
  let t_sizeof = Logic_const.term ~loc (TSizeOf ty) lty_sizeof in
  let t_size = size_from_memory_infos ~loc memory_infos in
  let t_size = Logic_const.term
    ~loc (TBinOp(Mult, t_sizeof, t_size)) lty_sizeof
  in
  let i = Interval.infer t_size in
  let malloc_stmt, env = match Typing.ty_of_interv i with
  | Typing.C_type IInt ->
    Typing.type_term ~use_gmp_opt:false ~ctx:Typing.c_int t_size;
    let e_size, env = term_to_exp kf (Env.push env) t_size in
    let e_size = Cil.constFold false e_size in
    let malloc_stmt =
      Misc.mk_call ~loc ~result:(Cil.var vi_at) "malloc" [e_size]
    in
    let malloc_block, env = Env.pop_and_get
      env malloc_stmt ~global_clear:true Env.Before
    in
    (* The following assert is because:
        1) [t_size is] a product of CONSTANT integers due to
          the over-approximations performed by [memory_infos_from_quantifs]
        2) We are in an [IInt] context
      Thus [e_size] is simply a C integer CONSTANT *)
    assert(List.length malloc_block.bstmts = 1);
    malloc_stmt, env
  | Typing.C_type _ | Typing.Gmp ->
    Error.not_yet
      ("\\at on purely logical variables that needs to allocate "
        ^ "too much memory (bigger than int_max bytes)")
  | Typing.Other ->
    Options.fatal "quantification over non-integer type is not part of E-ACSL"
  in
  let mf = {
      mf_malloc = malloc_stmt;
      mf_free = Misc.mk_call ~loc "free" [at_e]
    }
  in
  add_malloc_and_free_stmts kf mf;
  (* Index *)
  let t_index = index_from_mem_infos ~loc memory_infos in
  Typing.type_term ~use_gmp_opt:false ~ctx:Typing.c_int t_index;
  let e_index, env = term_to_exp kf env t_index in
  let e_index = Cil.constFold false e_index in
  (* Storing loops *)
  let e_addr =
    Cil.new_exp ~loc (BinOp(PlusPI, at_e, e_index, vi_at.vtype))
  in
  let lval_at_index = Mem e_addr, NoOffset in
  let storing_loops, env =
    mk_storing_loops ~loc kf env (Env.get_lscope env) lval_at_index pot
  in
  (* Put at label *)
  let env = put_block_at_label env storing_loops label in
  (* Returning *)
  let e = Cil.new_exp ~loc (Lval lval_at_index) in
  e, env