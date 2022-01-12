(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2021                                               *)
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

(** Generate C implementations of E-ACSL [\at()] terms and predicates. *)

open Cil_types
open Cil_datatype
open Analyses_types
open Analyses_datatype
module Error = Translation_error

(**************************************************************************)
(********************** Forward references ********************************)
(**************************************************************************)

let term_to_exp_ref
  : (adata:Assert.t ->
     ?inplace:bool ->
     kernel_function ->
     Env.t ->
     term ->
     exp * Assert.t * Env.t) ref
  =
  ref (fun ~adata:_ ?inplace:_ _kf _env _t ->
      Extlib.mk_labeled_fun "term_to_exp_ref")

let predicate_to_exp_ref
  : (adata:Assert.t ->
     ?inplace:bool ->
     ?name:string ->
     kernel_function ->
     ?rte:bool ->
     Env.t ->
     predicate ->
     exp * Assert.t * Env.t) ref
  =
  ref (fun ~adata:_ ?inplace:_ ?name:_ _kf ?rte:_ _env _p ->
      Extlib.mk_labeled_fun "predicate_to_exp_ref")

(*****************************************************************************)
(**************************** Handling memory ********************************)
(*****************************************************************************)

(** Remove all the bindings for [kf]. [Kf.Hashtbl] does not provide the
    [remove_all] function. Thus we need to keep calling [remove] until all
    entries are removed. *)
let rec remove_all tbl kf =
  if Kf.Hashtbl.mem tbl kf then begin
    Kf.Hashtbl.remove tbl kf;
    remove_all tbl kf
  end

module Malloc = struct
  let tbl = Kf.Hashtbl.create 7
  let add kf stmt = Kf.Hashtbl.add tbl kf stmt
  let find_all kf = Kf.Hashtbl.find_all tbl kf
  let remove_all kf = remove_all tbl kf
end

module Free = struct
  let tbl = Kf.Hashtbl.create 7
  let add kf stmt = Kf.Hashtbl.add tbl kf stmt
  let find_all kf = Kf.Hashtbl.find_all tbl kf
  let remove_all kf = remove_all tbl kf
end

(* ************************************************************************** *)
(* Helper functions for "with lscope" translation *)
(* ************************************************************************** *)

(* Builds the terms [t_size] and [t_shifted] from each
   [Lvs_quantif(tmin, lv, tmax)] from [lscope]
   where [t_size = tmax - tmin + (-1|0|1)] depending on whether the
                                          inequalities are strict or large
   and [t_shifted = lv - tmin + (-1|0)] (so that we start indexing at 0) *)
let rec sizes_and_shifts_from_quantifs ~loc kf lscope sizes_and_shifts =
  match lscope with
  | [] ->
    sizes_and_shifts
  | Lvs_quantif(tmin, _, _,  _, tmax) ::_
    when Misc.term_has_lv_from_vi tmin || Misc.term_has_lv_from_vi tmax ->
    Error.not_yet "\\at with logic variable linked to C variable"
  | Lvs_quantif(tmin, rel1, lv, rel2, tmax) :: lscope' ->
    let t_size = Logic_const.term ~loc (TBinOp(MinusA, tmax, tmin)) Linteger in
    let t_size = match rel1, rel2 with
      | Rle, Rle ->
        Logic_const.term
          ~loc
          (TBinOp(PlusA, t_size, Cil.lone ~loc ()))
          Linteger
      | Rlt, Rle | Rle, Rlt ->
        t_size
      | Rlt, Rlt ->
        Logic_const.term
          ~loc
          (TBinOp(MinusA, t_size, Cil.lone ~loc ()))
          Linteger
      | _ ->
        Options.fatal "Unexpected comparison operator"
    in
    let iv = Interval.(extract_ival (infer t_size)) in
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
    let t_size = match Ival.min_and_max iv with
      | _, Some max ->
        Logic_const.tint ~loc max
      | _, None ->
        Error.not_yet
          "\\at on purely logic variables and with quantifier that uses \
           too complex bound (E-ACSL cannot infer a finite upper bound to it)"
    in
    (* Index *)
    let t_lv = Logic_const.tvar ~loc lv in
    let t_shifted = match rel1 with
      | Rle ->
        Logic_const.term ~loc (TBinOp(MinusA, t_lv, tmin)) Linteger
      | Rlt ->
        let t =  Logic_const.term ~loc (TBinOp(MinusA, t_lv, tmin)) Linteger in
        Logic_const.term ~loc (TBinOp(MinusA, t, Cil.lone ~loc())) Linteger
      | _ ->
        Options.fatal "Unexpected comparison operator"
    in
    (* Returning *)
    let sizes_and_shifts = (t_size, t_shifted) :: sizes_and_shifts in
    sizes_and_shifts_from_quantifs ~loc kf lscope' sizes_and_shifts
  | (Lvs_let(_, t) | Lvs_global(_, t)) :: _
    when Misc.term_has_lv_from_vi t ->
    Error.not_yet "\\at with logic variable linked to C variable"
  | Lvs_let _ :: lscope' ->
    sizes_and_shifts_from_quantifs ~loc kf lscope' sizes_and_shifts
  | Lvs_formal _ :: _ ->
    Error.not_yet "\\at using formal variable of a logic function"
  | Lvs_global _ :: _ ->
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

(* Build the left-value corresponding to [*(at + index)]. *)
let lval_at_index ~loc kf env (e_at, t_index) =
  Typing.type_term
    ~use_gmp_opt:false
    ~ctx:Typing.c_int
    ~lenv:(Env.Local_vars.get env)
    t_index;
  let term_to_exp = !term_to_exp_ref in
  let e_index, _, env = term_to_exp ~adata:Assert.no_data kf env t_index in
  let e_index = Cil.constFold false e_index in
  let e_addr =
    Cil.new_exp ~loc (BinOp(PlusPI, e_at, e_index, Cil.typeOf e_at))
  in
  let lval_at_index = Mem e_addr, NoOffset in
  lval_at_index, env

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
  let product terms = List.fold_left
      (fun product t ->
         Logic_const.term ~loc (TBinOp(Mult, product, t)) Linteger)
      (Cil.lone ~loc ())
      terms
  in
  let sum, _ = List.fold_left
      (fun (index, sizes) (t_size, t_shifted) ->
         let pi_beta_j = product sizes in
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

(* [indexed_exp ~loc kf env e_at]
   [e_at] represents an array generated by [pretranslate_to_exp_with_lscope]
   and filled during the traversal of the [lscope].
   The function returns an expression indexing the array [e_at] using the
   variables created when traversing the [lscope] to retrieve the [\at] value
   during the traversal. *)
let indexed_exp ~loc kf env e_at =
  let lscope_vars = Lscope.get_all (Env.Logic_scope.get env) in
  let lscope_vars = List.rev lscope_vars in
  let sizes_and_shifts =
    sizes_and_shifts_from_quantifs ~loc kf lscope_vars []
  in
  let t_index = index_from_sizes_and_shifts ~loc sizes_and_shifts in
  let lval_at_index, env = lval_at_index ~loc kf env (e_at, t_index) in
  let e = Smart_exp.lval ~loc lval_at_index in
  e, env

(* ************************************************************************** *)
(* Translation *)
(* ************************************************************************** *)

let pretranslate_to_exp ~loc kf env pot =
  Options.debug ~level:4 "pre-translating %a in local environment '%a'"
    PredOrTerm.pretty pot
    Typing.Function_params_ty.pretty (Env.Local_vars.get env);
  let t_opt =
    match pot with
    | PoT_term t -> Some t
    | PoT_pred _ -> None
  in
  let e, _ , env =
    let adata = Assert.no_data in
    match pot with
    | PoT_term t -> !term_to_exp_ref ~adata ~inplace:true kf env t
    | PoT_pred p -> !predicate_to_exp_ref ~adata ~inplace:true kf env p
  in
  let ty = Cil.typeOf e in
  let _, var_e, env =
    Env.new_var
      ~loc
      ~scope:Function
      ~name:"at"
      env
      kf
      t_opt
      ty
      (fun var_vi var_e ->
         let init_set =
           if Gmp_types.Q.is_t ty then Rational.init_set else Gmp.init_set
         in
         [ init_set ~loc (Cil.var var_vi) var_e e ])
  in
  var_e, env

(* [pretranslate_to_exp_with_lscope ~loc ~lscope kf env pot] immediately
   translates the given [pred_or_term] in the current environment for each value
   of the given [lscope]. The result is stored in a dynamically allocated array
   and the expression returned is a pointer to this array.
   The function [indexed_exp] can later be used to retrieve the translation for
   a specific value of the [lscope]. *)
let pretranslate_to_exp_with_lscope ~loc ~lscope kf env pot =
  Options.debug ~level:4
    "pre-translating %a in local environment '%a' with lscope '%a'"
    PredOrTerm.pretty pot
    Typing.Function_params_ty.pretty (Env.Local_vars.get env)
    Lscope.D.pretty lscope;
  let term_to_exp = !term_to_exp_ref in
  let lscope_vars = Lscope.get_all lscope in
  let lscope_vars = List.rev lscope_vars in
  let sizes_and_shifts =
    sizes_and_shifts_from_quantifs ~loc kf lscope_vars []
  in
  (* Creating the pointer *)
  let ty = match pot with
    | PoT_pred _ ->
      Cil.intType
    | PoT_term t ->
      let lenv = (Env.Local_vars.get env) in
      begin match Typing.get_number_ty ~lenv t with
        | Typing.(C_integer _ | C_float _ | Nan) ->
          Typing.get_typ ~lenv t
        | Typing.(Rational | Real) ->
          Error.not_yet "\\at on purely logic variables and over real type"
        | Typing.Gmpz ->
          Error.not_yet "\\at on purely logic variables and over gmp type"
      end
  in
  let ty_ptr = TPtr(ty, []) in
  let _, e_at, env = Env.new_var
      ~loc
      ~name:"at"
      ~scope:Varname.Function
      env
      kf
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
         let lenv = Env.Local_vars.get env in
         Typing.type_term ~use_gmp_opt:false ~lenv t_size;
         let malloc_stmt =
           match Typing.get_number_ty ~lenv t_size with
           | Typing.C_integer IInt ->
             let e_size, _, _ =
               term_to_exp ~adata:Assert.no_data kf env t_size
             in
             let e_size = Cil.constFold false e_size in
             let malloc_stmt =
               Smart_stmt.call ~loc
                 ~result:(Cil.var vi)
                 "malloc"
                 [ e_size ]
             in
             malloc_stmt
           | Typing.(C_integer _ | C_float _ | Gmpz) ->
             Error.not_yet
               "\\at on purely logic variables that needs to allocate \
                too much memory (bigger than int_max bytes)"
           | Typing.(Rational | Real | Nan) ->
             Error.not_yet "quantification over non-integer type"
         in
         let free_stmt = Smart_stmt.call ~loc "free" [e] in
         (* The list of stmts returned by the current closure are inserted
            LOCALLY to the block where the new var is FIRST used, whatever scope
            is indicated to [Env.new_var].
            Thus we need to add [malloc] and [free] through dedicated functions.
         *)
         Malloc.add kf malloc_stmt;
         Free.add kf free_stmt;
         [])
  in
  (* Index *)
  let t_index = index_from_sizes_and_shifts ~loc sizes_and_shifts in
  (* Innermost block *)
  let mk_innermost_block env =
    let term_to_exp = !term_to_exp_ref ~adata:Assert.no_data ~inplace:true in
    let predicate_to_exp =
      !predicate_to_exp_ref ~adata:Assert.no_data ~inplace:true
    in
    match pot with
    | PoT_pred p ->
      let env = Env.push env in
      let lval, env = lval_at_index ~loc kf env (e_at, t_index) in
      let e, _, env = predicate_to_exp kf env p in
      let e = Cil.constFold false e in
      let storing_stmt =
        Smart_stmt.assigns ~loc ~result:lval e
      in
      let block, env =
        Env.pop_and_get env storing_stmt ~global_clear:false Env.After
      in
      (* We CANNOT return [block.bstmts] because it does NOT contain
         variable declarations. *)
      [ Smart_stmt.block_stmt block ], env
    | PoT_term t ->
      begin match Typing.get_number_ty ~lenv:(Env.Local_vars.get env) t with
        | Typing.(C_integer _ | C_float _ | Nan) ->
          let env = Env.push env in
          let lval, env = lval_at_index ~loc kf env (e_at, t_index) in
          let e, _, env = term_to_exp kf env t in
          let e = Cil.constFold false e in
          let storing_stmt =
            Smart_stmt.assigns ~loc ~result:lval e
          in
          let block, env =
            Env.pop_and_get env storing_stmt ~global_clear:false Env.After
          in
          (* We CANNOT return [block.bstmts] because it does NOT contain
             variable declarations. *)
          [ Smart_stmt.block_stmt block ], env
        | Typing.(Rational | Real) ->
          Error.not_yet "\\at on purely logic variables and over real type"
        | Typing.Gmpz ->
          Error.not_yet "\\at on purely logic variables and over gmp type"
      end
  in
  (* Storing loops *)
  let lscope_vars = Lscope.get_all lscope in
  let lscope_vars = List.rev lscope_vars in
  let env = Env.push env in
  let storing_loops_stmts, env =
    Loops.mk_nested_loops ~loc mk_innermost_block kf env lscope_vars
  in
  let storing_loops_block = Cil.mkBlock storing_loops_stmts in
  let storing_loops_block, env = Env.pop_and_get
      env
      (Smart_stmt.block_stmt storing_loops_block)
      ~global_clear:false
      Env.After
  in
  (* Put block in the current env *)
  let env = Env.add_stmt env (Smart_stmt.block_stmt storing_loops_block) in
  (* Returning *)
  e_at, env

let for_stmt env kf stmt =
  let at_for_stmt =
    Error.retrieve_preprocessing
      "blabla"
      Labels.Translation.at_for_stmt
      stmt
      Printer.pp_stmt
  in
  Options.debug ~level:4 "pre-translating %d ats for stmt %d at %a"
    (List.length at_for_stmt)
    stmt.sid
    Printer.pp_location (Stmt.loc stmt);
  let stmt_translations = PredOrTerm.Hashtbl.create 7 in
  List.fold_left
    (fun env ((_, _, lscope, pot, _) as at_data) ->
       let e_or_err, env =
         try
           match PredOrTerm.Hashtbl.find_opt stmt_translations pot with
           | Some e_or_err -> e_or_err, env
           | None ->
             let loc = Stmt.loc stmt in
             let e, env =
               if Lscope.is_used lscope pot then
                 pretranslate_to_exp_with_lscope ~loc ~lscope kf env pot
               else
                 pretranslate_to_exp ~loc kf env pot
             in
             (Result.Ok (Labels.Translation.Done e)), env
         with Error.(Typing_error _ | Not_yet _) as exn ->
           (Result.Error exn), env
       in
       PredOrTerm.Hashtbl.replace stmt_translations pot e_or_err;
       Labels.Translation.set ~force:true at_data e_or_err;
       env)
    env
    at_for_stmt

let to_exp ~loc ~adata kf env pot label =
  let kinstr = Env.get_kinstr env in
  let lscope = Env.Logic_scope.get env in
  try
    let e_or_err = Labels.Translation.get (kf, kinstr, lscope, pot, label) in
    let e, adata, env =
      match e_or_err with
      | Result.Ok (Labels.Translation.Done e) ->
        let e, env =
          if Lscope.is_used lscope pot then
            indexed_exp ~loc kf env e
          else
            e, env
        in
        let adata, env =
          Assert.register_pred_or_term ~loc env pot e adata
        in
        e, adata, env
      | Result.Ok Labels.Translation.Inplace -> begin
          match pot with
          | PoT_term t -> !term_to_exp_ref ~adata ~inplace:true kf env t
          | PoT_pred p -> !predicate_to_exp_ref ~adata ~inplace:true kf env p
        end
      | Result.Ok Labels.Translation.Queued ->
        let potstr =
          match pot with PoT_term _ -> "term" | PoT_pred _ -> "predicate"
        in
        Options.abort ~source:(fst loc)
          "%s '%a' was used before being translated.@ \
           This usually happen when using a label defined after the place@ \
           where the %s should be translated"
          potstr
          PredOrTerm.pretty pot
          potstr
      | Result.Error exn ->
        Env.Context.save env;
        raise exn
    in
    e, adata, env
  with Not_found ->
    Options.fatal ~source:(fst loc) "no translation for %a"
      Labels.pp_at_data (kf, kinstr, lscope, pot, label)
