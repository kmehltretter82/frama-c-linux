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

(* Remove all the bindings for [kf]. [Cil_datatype.Kf.Hashtbl] does not
  provide the [remove_all] function. Thus we need to keep calling [remove]
  until all entries are removed. *)
let rec remove_all tbl kf =
  try
    ignore(Cil_datatype.Kf.Hashtbl.find tbl kf);
    Cil_datatype.Kf.Hashtbl.remove tbl kf;
    remove_all tbl kf;
  with Not_found ->
    ()

module Malloc = struct
  let tbl = Cil_datatype.Kf.Hashtbl.create 7
  let add kf stmt = Cil_datatype.Kf.Hashtbl.add tbl kf stmt
  let find_all kf = Cil_datatype.Kf.Hashtbl.find_all tbl kf
  let remove_all kf = remove_all tbl kf
end

module Free = struct
  let tbl = Cil_datatype.Kf.Hashtbl.create 7
  let add kf stmt = Cil_datatype.Kf.Hashtbl.add tbl kf stmt
  let find_all kf = Cil_datatype.Kf.Hashtbl.find_all tbl kf
  let remove_all kf = remove_all tbl kf
end

(**************************************************************************)
(*************************** Translation **********************************)
(**************************************************************************)

(* Builds the terms [t_size] and [t_shifted] from each
  [Lvs_quantif(tmin, lv, tmax)] from [lscope]
  where [t_size = tmax - tmin + 1] (+1 because the inequalities are large
                                  due to previous normalization)
  and [t_shifted = lv - tmin] (so that we start indexing at 0) *)
let rec sizes_and_shifts_from_quantifs ~loc kf lscope sizes_and_shifts =
  match lscope with
  | [] ->
    sizes_and_shifts
  | Lscope.Lvs_quantif(tmin, _, tmax) ::_
    when Misc.term_has_lv_from_vi tmin || Misc.term_has_lv_from_vi tmax ->
    Error.not_yet "\\at with logic variable linked to C variable"
  | Lscope.Lvs_quantif(tmin, lv, tmax) :: lscope' ->
    let t_size = Logic_const.term ~loc (TBinOp(MinusA, tmax, tmin)) Linteger in
    let t_size =
      Logic_const.term ~loc (TBinOp(PlusA, t_size, Cil.lone ~loc ())) Linteger
    in
    let i = Interval.infer t_size in
    (* The EXACT amount of memory that is needed can be known at runtime. This
      is because the tightest bounds for the variables can be known at runtime.
      Example: In the following predicate
        [\exists integer u; 9 <= u <= 13 &&
         \forall integer v; -5 < v <= (u <= 11 ? u + 6 : u - 9) ==>
           \at(u + v > 0, K)]
        the upper bound [M] for [v] depends on [u].
        In chronological order, [M] equals to 15, 16, 17, 3 and 4.
        Thus the tightest upper bound for [v] is [max(M)=17].
      HOWEVER, computing that exact information requires extra nested loops,
      prior to the [malloc] stmts, that will try all the possible values of the
      variables involved in the bounds.
      Instead of sacrificing time over memory (by performing these extra
      computations), we consider that sacrificing memory over time is more
      beneficial. In particular, though we may allocate more memory than
      needed, the number of reads/writes into it is the same in both cases.
      Conclusion: over-approximate [t_size] *)
    let t_size = match Ival.min_and_max i with
    | _, Some max ->
      Logic_const.tint ~loc max
    | _, None ->
      Error.not_yet
        ("\\at on purely logic variables and with quantifier that uses " ^
          "too complex bound " ^
          "(E-ACSL cannot infer a finite upper bound to it)")
    in
    (* Index *)
    let t_lv = Logic_const.tvar ~loc lv in
    let t_shifted =
      Logic_const.term ~loc (TBinOp(MinusA, t_lv, tmin)) Linteger
    in
    (* Returning *)
    let sizes_and_shifts = (t_size, t_shifted) :: sizes_and_shifts in
    sizes_and_shifts_from_quantifs ~loc kf lscope' sizes_and_shifts
  | (Lscope.Lvs_let(_, t) | Lscope.Lvs_global(_, t)) :: _
    when Misc.term_has_lv_from_vi t ->
    Error.not_yet "\\at with logic variable linked to C variable"
  | Lscope.Lvs_let _ :: lscope' ->
    sizes_and_shifts_from_quantifs ~loc kf lscope' sizes_and_shifts
  | Lscope.Lvs_formal _ :: _ ->
    Error.not_yet "\\at using formal variable of a logic function"
  | Lscope.Lvs_global _ :: _ ->
    Error.not_yet "\\at using global logic variable"

let size_from_sizes_and_shifts ~loc = function
  | [] ->
    (* No quantified variable. But still need to allocate [1*sizeof(_)] amount
      of memory to store purely logic variables that are NOT quantified
      (example: from \let). *)
    Cil.lone ~loc ()
  | (size, _) :: sizes_and_shifts ->
    List.fold_left
      (fun t_size (t_s, _) ->
        Logic_const.term ~loc (TBinOp(Mult, t_size, t_s)) Linteger)
      size
      sizes_and_shifts

let append_block_of_env_to_block env block =
  let block_stmt = Cil.mkStmt ~valid_sid:true (Block block) in
  let block, env =
    Env.pop_and_get env block_stmt ~global_clear:false Env.After
  in
  block, env

(* Build the left-value corresponding to [*(at + index)]. *)
let lval_at_index ~loc kf env (e_at, vi_at, t_index) =
  Typing.type_term ~use_gmp_opt:false ~ctx:Typing.c_int t_index;
  let term_to_exp = !term_to_exp_ref in
  let e_index, env = term_to_exp kf env t_index in
  let e_index = Cil.constFold false e_index in
  let e_addr =
    Cil.new_exp ~loc (BinOp(PlusPI, e_at, e_index, vi_at.vtype))
  in
  let lval_at_index = Mem e_addr, NoOffset in
  lval_at_index, env

(* [mk_storing_loops] creates the nested loops that are used to store the
  different possible values of [pot].
  These loops are similar to those generated by [Quantif], with the difference
  that the aim of the innermost block is to store values,
  not to check the validity of some (quantified) predicate. *)
let rec mk_storing_loops ~loc kf env lscope (e_at, vi_at, t_index) pot =
  let term_to_exp = !term_to_exp_ref in
  let named_predicate_to_exp = !predicate_to_exp_ref in
  match lscope, pot with
  | [], Misc.PoT_pred p ->
    let env = Env.push env in
    let lval, env = lval_at_index ~loc kf env (e_at, vi_at, t_index) in
    let e, env = named_predicate_to_exp kf env p in
    let storing_stmt =
      Cil.mkStmtOneInstr ~valid_sid:true (Set(lval, e, loc))
    in
    let block, env =
      Env.pop_and_get env storing_stmt ~global_clear:false Env.After
    in
    block, env
  | [], Misc.PoT_term t ->
    begin match Typing.get_integer_ty t with
    | Typing.C_type _ | Typing.Other ->
      let env = Env.push env in
      let lval, env = lval_at_index ~loc kf env (e_at, vi_at, t_index) in
      let e, env = term_to_exp kf env t in
      let storing_stmt =
        Cil.mkStmtOneInstr ~valid_sid:true (Set(lval, e, loc))
      in
      let block, env =
        Env.pop_and_get env storing_stmt ~global_clear:false Env.After
      in
      block, env
    | Typing.Gmp ->
      Error.not_yet "\\at on purely logic variables and over gmp type"
    end
  | Lscope.Lvs_quantif(tmin, lv, tmax) :: lscope', pot ->
    (* TODO: a refactor with [Quantif] may be possible for this case *)
    let vi_of_lv_old = Env.Logic_binding.get env lv in
    let env = Env.push env in
    let vi_of_lv, _, env =
      (* We need to redeclare the lv thus new varinfo needed *)
      Env.Logic_binding.add ~ty:vi_of_lv_old.vtype env lv
    in
    let t_lv = Logic_const.tvar ~loc lv in
    (* Guard *)
    let guard =
      Logic_const.term ~loc (TBinOp(Le, t_lv, tmax)) (Ctype Cil.intType)
    in
    Typing.type_term ~use_gmp_opt:false ~ctx:Typing.c_int guard;
    let guard_exp, env = term_to_exp kf env guard in
    (* Break *)
    let break_stmt = Cil.mkStmt ~valid_sid:true (Break guard_exp.eloc) in
    (* Inner loop *)
    let loop', env =
      mk_storing_loops ~loc kf env lscope' (e_at, vi_at, t_index) pot
    in
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
    | Typing.C_type _ | Typing.Gmp ->
      Gmpz.init_set ~loc (Cil.var vi_of_lv) (Cil.evar vi_of_lv) plus_one_exp
    | Typing.Other ->
      assert false
    in
    (* If guard is satisfiable then inner loop, else break *)
    let if_stmt = Cil.mkStmt
      ~valid_sid:true
      (If(guard_exp,
        Cil.mkBlock [ loop'; plus_one_stmt ],
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
    | Typing.C_type _ | Typing.Gmp ->
      Gmpz.init_set ~loc (Cil.var vi_of_lv) (Cil.evar vi_of_lv) tmin_exp
    | Typing.Other ->
      assert false
    in
    (* The whole block *)
    let block = Cil.mkBlock [set_tmin; loop] in
    let b, env = append_block_of_env_to_block env block in
    let env = Env.Logic_binding.set env lv vi_of_lv_old in
    b, env
  | Lscope.Lvs_let(lv, t) :: lscope', pot ->
    let vi_of_lv_old = Env.Logic_binding.get env lv in
    let env = Env.push env in
    let vi_of_lv, exp_of_lv, env =
     (* We need to redeclare the lv thus new varinfo needed *)
      Env.Logic_binding.add ~ty:vi_of_lv_old.vtype env lv
    in
    let e, env = term_to_exp kf env t in
    let let_stmt = Gmpz.init_set ~loc (Cil.var vi_of_lv) exp_of_lv  e in
    let block, env =
      mk_storing_loops ~loc kf env lscope' (e_at, vi_at, t_index) pot
    in
    (* The whole block *)
    block.bstmts <- let_stmt :: block.bstmts;
    let b, env = append_block_of_env_to_block env block in
    let env = Env.Logic_binding.set env lv vi_of_lv_old in
    b, env
  | Lscope.Lvs_formal _ :: _, _ ->
    Error.not_yet "\\at using formal variable of a logic function"
  | Lscope.Lvs_global _ :: _ , _->
    Error.not_yet "\\at using global logic variable"

(* Associate to each possible tuple of quantifiers
  a unique index from the set {n | 0 <= n < n_max}.
  That index will serve to identify the memory location where the evaluation
  of the term/predicate is stored for the given tuple of quantifier.
  The following gives the smallest set of such indexes (hence we use the
  smallest amount of memory in some respect):
  To (t_shifted_n, t_shifted_n-1, ..., t_shifted_1)
  where 0 <= t_shifted_i < beta_i
  corresponds: \sum_{i=1}^n( t_shifted_i * \pi_{j=1}^{i-1}(beta_j) ) *)
let index_from_sizes_and_shifts ~loc sizes_and_shifts =
  let sum, _ = List.fold_left
    (fun (index, sizes) (t_size, t_shifted) ->
      let pi_beta_j sizes = List.fold_left
        (fun pi_beta_j t_size ->
          Logic_const.term ~loc (TBinOp(Mult, pi_beta_j, t_size)) Linteger)
        (Cil.lone ~loc ())
        sizes
      in
      let pi_beta_j = pi_beta_j sizes in
      let bi_mult_pi_beta_j =
        Logic_const.term ~loc (TBinOp(Mult, t_shifted, pi_beta_j)) Linteger
      in
      let sum = Logic_const.term
        ~loc
        (TBinOp(PlusA, bi_mult_pi_beta_j, index))
        Linteger
      in
      sum, t_size :: sizes)
    (Cil.lzero ~loc (), [])
    sizes_and_shifts
  in
  sum

let put_block_at_label env block label =
  let stmt = Label.get_stmt (Env.get_visitor env) label in
  let env_ref = ref env in
  let o = object
    inherit Visitor.frama_c_inplace
    method !vstmt_aux stmt =
      assert (!env_ref == env);
      env_ref := Env.extend_stmt_in_place env stmt ~label block;
      Cil.ChangeTo stmt
  end
  in
  let bhv = Env.get_behavior env in
  ignore(Visitor.visitFramacStmt o (Cil.get_stmt bhv stmt));
  !env_ref

let to_exp ~loc kf env pot label =
  let term_to_exp = !term_to_exp_ref in
  let lscope_vars = Lscope.get_all (Env.Logic_scope.get env) in
  let sizes_and_shifts =
    sizes_and_shifts_from_quantifs ~loc kf lscope_vars []
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
      Error.not_yet "\\at on purely logic variables and over gmp type"
    end
  in
  let ty_ptr = TPtr(ty, []) in
  let vi_at, e_at, env = Env.new_var
    ~loc
    ~name:"at"
    ~scope:Env.Function
    env
    None
    ty_ptr
    (fun vi e ->
      (* Handle [malloc] and [free] stmts *)
      let lty_sizeof = Ctype Cil.(theMachine.typeOfSizeOf) in
      let t_sizeof = Logic_const.term ~loc (TSizeOf ty) lty_sizeof in
      let t_size = size_from_sizes_and_shifts ~loc sizes_and_shifts in
      let t_size =
        Logic_const.term ~loc (TBinOp(Mult, t_sizeof, t_size)) lty_sizeof
      in
      Typing.type_term ~use_gmp_opt:false t_size;
      let malloc_stmt = match Typing.get_integer_ty t_size with
      | Typing.C_type IInt ->
        let e_size, _ = term_to_exp kf env t_size in
        let e_size = Cil.constFold false e_size in
        let malloc_stmt =
          Misc.mk_call ~loc ~result:(Cil.var vi) "malloc" [e_size]
        in
        malloc_stmt
      | Typing.C_type _ | Typing.Gmp ->
        Error.not_yet
          ("\\at on purely logic variables that needs to allocate "
            ^ "too much memory (bigger than int_max bytes)")
      | Typing.Other ->
        Options.fatal
          "quantification over non-integer type is not part of E-ACSL"
      in
      let free_stmt = Misc.mk_call ~loc "free" [e] in
      (* The list of stmts returned by the current closure are inserted
        LOCALLY to the block where the new var is FIRST used, whatever scope
        is indicated to [Env.new_var].
        Thus we need to add [malloc] and [free] through dedicated functions. *)
      Malloc.add kf malloc_stmt;
      Free.add kf free_stmt;
      [])
  in
  (* Index *)
  let t_index = index_from_sizes_and_shifts ~loc sizes_and_shifts in
  (* Storing loops *)
  let lscope_vars = Lscope.get_all (Env.Logic_scope.get env) in
  let storing_loops, env =
    mk_storing_loops ~loc kf env lscope_vars (e_at, vi_at, t_index) pot
    (* [t_index] MUST NOT be translated here because the logic bindings
      will differ once inside [mk_storing_loops] *)
  in
  (* Put at label *)
  let env = put_block_at_label env storing_loops label in
  (* Returning *)
  let lval_at_index, env = lval_at_index ~loc kf env (e_at, vi_at, t_index) in
  let e = Cil.new_exp ~loc (Lval lval_at_index) in
  e, env