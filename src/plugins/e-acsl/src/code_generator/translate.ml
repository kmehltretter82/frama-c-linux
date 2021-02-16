(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2020                                               *)
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

module E_acsl_label = Label
open Cil_types
open Cil_datatype

(** *)

let dkey = Options.dkey_translation

(* internal to [predicate_to_exp] but put it outside in order to not add
   extra tedious parameter.
   It is [true] iff we are currently visiting \valid. *)
let is_visiting_valid = ref false

(* ************************************************************************** *)
(* Transforming terms and predicates into C expressions (if any) *)
(* ************************************************************************** *)

let relation_to_binop = function
  | Rlt -> Lt
  | Rgt -> Gt
  | Rle -> Le
  | Rge -> Ge
  | Req -> Eq
  | Rneq -> Ne

let name_of_mpz_arith_bop = function
  | PlusA -> "__gmpz_add"
  | MinusA -> "__gmpz_sub"
  | Mult -> "__gmpz_mul"
  | Div -> "__gmpz_tdiv_q"
  | Mod -> "__gmpz_tdiv_r"
  | BAnd -> "__gmpz_and"
  | BOr -> "__gmpz_ior"
  | BXor -> "__gmpz_xor"
  | Shiftlt -> "__gmpz_mul_2exp"
  | Shiftrt -> "__gmpz_tdiv_q_2exp"
  | Lt | Gt | Le | Ge | Eq | Ne | LAnd | LOr | PlusPI | IndexPI | MinusPI
  | MinusPP -> assert false

(* Type of a string that represents a number.
   Used when a string is required to encode a constant number because it is not
   representable in any C type  *)
type strnum =
  | Str_Z         (* integers *)
  | Str_R         (* reals *)
  | C_number      (* integers and floats included *)

(* convert [e] in a way that it is compatible with the given typing context. *)
let add_cast ~loc ?name env kf ctx strnum t_opt e =
  let mk_mpz e =
    let _, e, env =
      Env.new_var
        ~loc
        ?name
        env
        kf
        t_opt
        (Gmp_types.Z.t ())
        (fun lv v -> [ Gmp.init_set ~loc (Cil.var lv) v e ])
    in
    e, env
  in
  let e, env = match strnum with
    | Str_Z -> mk_mpz e
    | Str_R -> Rational.create ~loc ?name e env kf t_opt
    | C_number -> e, env
  in
  match ctx with
  | None ->
    e, env
  | Some ctx ->
    let ty = Cil.typeOf e in
    match Gmp_types.Z.is_t ty, Gmp_types.Z.is_t ctx with
    | true, true ->
      (* Z --> Z *)
      e, env
    | false, true ->
      if Gmp_types.Q.is_t ty then
        (* R --> Z *)
        Rational.cast_to_z ~loc ?name e env
      else
        (* C integer --> Z *)
        let e =
          if not (Cil.isIntegralType ty) && strnum = C_number then
            (* special case for \null that must be casted to long: it is the
               only non integral value that can be seen as an integer, while the
               type system infers that it is C-representable (see
               tests/runtime/null.i) *)
            Cil.mkCast Cil.longType e (* \null *)
          else
            e
        in
        mk_mpz e
    | _, false ->
      if Gmp_types.Q.is_t ctx then
        if Gmp_types.Q.is_t (Cil.typeOf e) then (* R --> R *)
          e, env
        else (* C integer or Z --> R *)
          Rational.create ~loc ?name e env kf t_opt
      else if Gmp_types.Z.is_t ty || strnum = Str_Z then
        (* Z --> C type or the integer is represented by a string:
           anyway, it fits into a C integer: convert it *)
        let fname, new_ty =
          if Cil.isSignedInteger ctx then "__gmpz_get_si", Cil.longType
          else "__gmpz_get_ui", Cil.ulongType
        in
        let _, e, env =
          Env.new_var
            ~loc
            ?name
            env
            kf
            None
            new_ty
            (fun v _ ->
               [ Smart_stmt.rtl_call ~loc
                   ~result:(Cil.var v)
                   ~prefix:""
                   fname
                   [ e ] ])
        in
        e, env
      else if Gmp_types.Q.is_t ty || strnum = Str_R then
        (* R --> C type or the real is represented by a string *)
        Rational.add_cast ~loc ?name e env kf ctx
      else
        (* C type --> another C type *)
        Cil.mkCastT ~force:false ~oldt:ty ~newt:ctx e, env

let constant_to_exp ~loc t c =
  let mk_real s =
    let s = Rational.normalize_str s in
    Cil.mkString ~loc s, Str_R
  in
  match c with
  | Integer(n, _repr) ->
    let ity = Typing.get_number_ty t in
    (match ity with
     | Typing.Nan -> assert false
     | Typing.Real -> Error.not_yet "real number constant"
     | Typing.Rational -> mk_real (Integer.to_string n)
     | Typing.Gmpz ->
       (* too large integer *)
       Cil.mkString ~loc (Integer.to_string n), Str_Z
     | Typing.C_float fkind ->
       Cil.kfloat ~loc fkind (Int64.to_float (Integer.to_int64 n)), C_number
     | Typing.C_integer kind ->
       let cast = Typing.get_cast t in
       match cast, kind with
       | Some ty, (ILongLong | IULongLong) when Gmp_types.Z.is_t ty ->
         (* too large integer *)
         Cil.mkString ~loc (Integer.to_string n), Str_Z
       | Some ty, _ when Gmp_types.Q.is_t ty ->
         mk_real (Integer.to_string n)
       | (None | Some _), _ ->
         (* do not keep the initial string representation because the generated
            constant must reflect its type computed by the type system. For
            instance, when translating [INT_MAX+1], we must generate a [long
            long] addition and so [1LL]. If we keep the initial string
            representation, the kind would be ignored in the generated code and
            so [1] would be generated. *)
         Cil.kinteger64 ~loc ~kind n, C_number)
  | LStr s -> Cil.new_exp ~loc (Const (CStr s)), C_number
  | LWStr s -> Cil.new_exp ~loc (Const (CWStr s)), C_number
  | LChr c -> Cil.new_exp ~loc (Const (CChr c)), C_number
  | LReal lr ->
    if lr.r_lower = lr.r_upper
    then Cil.kfloat ~loc FDouble lr.r_nearest, C_number
    else mk_real lr.r_literal
  | LEnum e -> Cil.new_exp ~loc (Const (CEnum e)), C_number

let conditional_to_exp ?(name="if") loc kf t_opt e1 (e2, env2) (e3, env3) =
  let env = Env.pop (Env.pop env3) in
  match e1.enode with
  | Const(CInt64(n, _, _)) when Integer.is_zero n ->
    e3, Env.transfer ~from:env3 env
  | Const(CInt64(n, _, _)) when Integer.is_one n ->
    e2, Env.transfer ~from:env2 env
  | _ ->
    let ty = match t_opt with
      | None (* predicate *) -> Cil.intType
      | Some t -> Typing.get_typ t
    in
    let _, e, env =
      Env.new_var
        ~loc
        ~name
        env
        kf
        t_opt
        ty
        (fun v ev ->
           let lv = Cil.var v in
           let ty = Cil.typeOf ev in
           let init_set =
             assert (not (Gmp_types.Q.is_t ty));
             Gmp.init_set
           in
           let affect e = init_set ~loc lv ev e in
           let then_blk, _ =
             let s = affect e2 in
             Env.pop_and_get env2 s ~global_clear:false Env.Middle
           in
           let else_blk, _ =
             let s = affect e3 in
             Env.pop_and_get env3 s ~global_clear:false Env.Middle
           in
           [ Smart_stmt.if_stmt ~loc ~cond:e1 then_blk ~else_blk ])
    in
    e, env

let rec thost_to_host kf env th = match th with
  | TVar { lv_origin = Some v } ->
    Var v, env, v.vname
  | TVar ({ lv_origin = None } as logic_v) ->
    let v' = Env.Logic_binding.get env logic_v in
    Var v', env, logic_v.lv_name
  | TResult _typ ->
    let lhost = Misc.result_lhost kf in
    (match lhost with
     | Var v -> Var v, env, "result"
     | _ -> assert false)
  | TMem t ->
    let e, env = term_to_exp kf env t in
    Mem e, env, ""

and toffset_to_offset ?loc kf env = function
  | TNoOffset -> NoOffset, env
  | TField(f, offset) ->
    let offset, env = toffset_to_offset ?loc kf env offset in
    Field(f, offset), env
  | TIndex(t, offset) ->
    let e, env = term_to_exp kf env t in
    let offset, env = toffset_to_offset kf env offset in
    Index(e, offset), env
  | TModel _ -> Env.not_yet env "model"

and tlval_to_lval kf env (host, offset) =
  let host, env, name = thost_to_host kf env host in
  let offset, env = toffset_to_offset kf env offset in
  let name = match offset with NoOffset -> name | Field _ | Index _ -> "" in
  (host, offset), env, name

(* the returned boolean says that the expression is an mpz_string;
   the returned string is the name of the generated variable corresponding to
   the term. *)
and context_insensitive_term_to_exp kf env t =
  let loc = t.term_loc in
  match t.term_node with
  | TConst c ->
    let c, strnum = constant_to_exp ~loc t c in
    c, env, strnum, ""
  | TLval lv ->
    let lv, env, name = tlval_to_lval kf env lv in
    Smart_exp.lval ~loc lv, env, C_number, name
  | TSizeOf ty -> Cil.sizeOf ~loc ty, env, C_number, "sizeof"
  | TSizeOfE t ->
    let e, env = term_to_exp kf env t in
    Cil.sizeOf ~loc (Cil.typeOf e), env, C_number, "sizeof"
  | TSizeOfStr s ->
    Cil.new_exp ~loc (SizeOfStr s), env, C_number, "sizeofstr"
  | TAlignOf ty -> Cil.new_exp ~loc (AlignOf ty), env, C_number, "alignof"
  | TAlignOfE t ->
    let e, env = term_to_exp kf env t in
    Cil.new_exp ~loc (AlignOfE e), env, C_number, "alignof"
  | TUnOp(Neg | BNot as op, t') ->
    let ty = Typing.get_typ t in
    let e, env = term_to_exp kf env t' in
    if Gmp_types.Z.is_t ty then
      let name, vname = match op with
        | Neg -> "__gmpz_neg", "neg"
        | BNot -> "__gmpz_com", "bnot"
        | LNot -> assert false
      in
      let _, e, env =
        Env.new_var_and_mpz_init
          ~loc
          env
          kf
          ~name:vname
          (Some t)
          (fun _ ev -> [ Smart_stmt.rtl_call ~loc ~prefix:"" name [ ev; e ] ])
      in
      e, env, C_number, ""
    else if Gmp_types.Q.is_t ty then
      Env.not_yet env "reals: Neg | BNot"
    else
      Cil.new_exp ~loc (UnOp(op, e, ty)), env, C_number, ""
  | TUnOp(LNot, t) ->
    let ty = Typing.get_op t in
    if Gmp_types.Z.is_t ty then
      (* [!t] is converted into [t == 0] *)
      let zero = Logic_const.tinteger 0 in
      let ctx = Typing.get_number_ty t in
      Typing.type_term ~use_gmp_opt:true ~ctx zero;
      let e, env =
        comparison_to_exp kf ~loc ~name:"not" env Typing.gmpz Eq t zero (Some t)
      in
      e, env, C_number, ""
    else begin
      assert (Cil.isIntegralType ty);
      let e, env = term_to_exp kf env t in
      Cil.new_exp ~loc (UnOp(LNot, e, Cil.intType)), env, C_number, ""
    end
  | TBinOp(PlusA | MinusA | Mult as bop, t1, t2) ->
    let ty = Typing.get_typ t in
    let e1, env = term_to_exp kf env t1 in
    let e2, env = term_to_exp kf env t2 in
    if Gmp_types.Z.is_t ty then
      let name = name_of_mpz_arith_bop bop in
      let mk_stmts _ e = [ Smart_stmt.rtl_call ~loc
                             ~prefix:""
                             name
                             [ e; e1; e2 ] ] in
      let name = Misc.name_of_binop bop in
      let _, e, env =
        Env.new_var_and_mpz_init ~loc ~name env kf (Some t) mk_stmts
      in
      e, env, C_number, ""
    else if Gmp_types.Q.is_t ty then
      let e, env = Rational.binop ~loc bop e1 e2 env kf (Some t) in
      e, env, C_number, ""
    else begin
      assert (Logic_typing.is_integral_type t.term_type);
      Cil.new_exp ~loc (BinOp(bop, e1, e2, ty)), env, C_number, ""
    end
  | TBinOp(Div | Mod as bop, t1, t2) ->
    let ty = Typing.get_typ t in
    let e1, env = term_to_exp kf env t1 in
    let e2, env = term_to_exp kf env t2 in
    if Gmp_types.Z.is_t ty then
      (* TODO: preventing division by zero should not be required anymore.
         RTE should do this automatically. *)
      let ctx = Typing.get_number_ty t in
      let t = Some t in
      let name = name_of_mpz_arith_bop bop in
      (* [TODO] can now do better since the type system got some info about
         possible values of [t2] *)
      (* guarding divisions and modulos *)
      let zero = Logic_const.tinteger 0 in
      Typing.type_term ~use_gmp_opt:true ~ctx zero;
      (* do not generate [e2] from [t2] twice *)
      let guard, env =
        let name = Misc.name_of_binop bop ^ "_guard" in
        comparison_to_exp
          ~loc kf env Typing.gmpz ~e1:e2 ~name Ne t2 zero t
      in
      let p = Logic_const.prel ~loc (Rneq, t2, zero) in
      let mk_stmts _v e =
        assert (Gmp_types.Z.is_t ty);
        let cond =
          Smart_stmt.runtime_check
            (Env.annotation_kind env)
            kf
            guard
            p
        in
        Env.add_assert kf cond p;
        let instr = Smart_stmt.rtl_call ~loc ~prefix:"" name [ e; e1; e2 ] in
        [ cond; instr ]
      in
      let name = Misc.name_of_binop bop in
      let _, e, env = Env.new_var_and_mpz_init ~loc ~name env kf t mk_stmts in
      e, env, C_number, ""
    else if Gmp_types.Q.is_t ty then
      let e, env = Rational.binop ~loc bop e1 e2 env kf (Some t) in
      e, env, C_number, ""
    else begin
      assert (Logic_typing.is_integral_type t.term_type);
      (* no guard required since RTEs are generated separately *)
      Cil.new_exp ~loc (BinOp(bop, e1, e2, ty)), env, C_number, ""
    end
  | TBinOp(Lt | Gt | Le | Ge | Eq | Ne as bop, t1, t2) ->
    (* comparison operators *)
    let ity = Typing.get_integer_op t in
    let e, env = comparison_to_exp ~loc kf env ity bop t1 t2 (Some t) in
    e, env, C_number, ""
  | TBinOp((Shiftlt | Shiftrt) as bop, t1, t2) ->
    (* left/right shift *)
    let ty = Typing.get_typ t in
    let e1, env = term_to_exp kf env t1 in
    let e2, env = term_to_exp kf env t2 in
    if Gmp_types.Z.is_t ty then
      (* If the given term is an lvalue variable or a cast from an lvalue
         variable, retrieve the name of this variable. Otherwise return
         default *)
      let rec term_to_name t =
        match t.term_node with
        | TConst _ -> "cst_"
        | TLval (TVar { lv_name }, _) -> lv_name ^ "_"
        | TCastE (_, t) -> term_to_name t
        | TLogic_coerce (_, t) -> term_to_name t
        | _ -> ""
      in
      let ctx = Typing.get_number_ty t in
      let bop_name = Misc.name_of_binop bop in
      let e1_name = term_to_name t1 in
      let e2_name = term_to_name t2 in
      let zero = Logic_const.tinteger 0 in
      Typing.type_term ~use_gmp_opt:true ~ctx zero;

      (* Check that e2 is representable in mp_bitcnt_t *)
      let coerce_guard, env =
        let name = e2_name ^ bop_name ^ "_guard" in
        let _vi, e, env =
          Env.new_var
            ~loc
            ~scope:Varname.Block
            ~name
            env
            kf
            None
            Cil.intType
            (fun vi _e ->
               let result = Cil.var vi in
               let fname = "__gmpz_fits_ulong_p" in
               [ Smart_stmt.rtl_call ~loc ~result ~prefix:"" fname [ e2 ] ])
        in
        e, env
      in
      (* Coerce e2 to mp_bitcnt_t *)
      let mk_coerce_stmts vi _e =
        let coerce_guard_cond =
          let max_bitcnt =
            Cil.max_unsigned_number (Cil.bitsSizeOf (Gmp_types.bitcnt_t ()))
          in
          let max_bitcnt_term = Cil.lconstant ~loc max_bitcnt in
          let pred =
            Logic_const.pand
              ~loc
              (Logic_const.prel ~loc (Rle, zero, t2),
               Logic_const.prel ~loc (Rle, t2, max_bitcnt_term))
          in
          let pname = bop_name ^ "_rhs_fits_in_mp_bitcnt_t" in
          let pred = { pred with pred_name = pname :: pred.pred_name } in
          let cond = Smart_stmt.runtime_check
              Smart_stmt.RTE
              kf
              coerce_guard
              pred
          in
          Env.add_assert kf cond pred;
          cond
        in
        let result = Cil.var vi in
        let name = "__gmpz_get_ui" in
        let instr = Smart_stmt.rtl_call ~loc ~result ~prefix:"" name [ e2 ] in
        [ coerce_guard_cond; instr ]
      in
      let name = e2_name ^ bop_name ^ "_coerced" in
      let _e2_as_bitcnt_vi, e2_as_bitcnt_e, env =
        Env.new_var
          ~loc
          ~scope:Varname.Block
          ~name
          env
          kf
          None
          (Gmp_types.bitcnt_t ())
          mk_coerce_stmts
      in

      (* Create the shift instruction *)
      let mk_shift_instr result_e =
        let name = name_of_mpz_arith_bop bop in
        Smart_stmt.rtl_call ~loc
          ~prefix:""
          name
          [ result_e; e1; e2_as_bitcnt_e ]
      in

      (* Put t in an option to use with comparison_to_exp and
         Env.new_var_and_mpz_init *)
      let t = Some t in

      (* TODO: let RTE generate the undef behaviors assertions *)

      (* Boolean to choose whether the guard [e1 >= 0] should be added *)
      let should_guard_e1 =
        match bop with
        | Shiftlt -> Kernel.LeftShiftNegative.get ()
        | Shiftrt -> Kernel.RightShiftNegative.get ()
        | _ -> assert false
      in

      (* Create the statements to initialize [e1 shift e2] *)
      let e1_guard_opt, env =
        if should_guard_e1 then
          (* Future RTE:
             if (warn left shift negative and left shift)
                or (warn right shift negative and right shift)
             then check e1 >= 0 *)
          let e1_guard, env =
            let name = e1_name ^ bop_name ^ "_guard" in
            comparison_to_exp
              ~loc kf env Typing.gmpz ~e1 ~name Ge t1 zero t
          in
          let e1_guard_cond =
            let pred = Logic_const.prel ~loc (Rge, t1, zero) in
            let cond = Smart_stmt.runtime_check
                Smart_stmt.RTE
                kf
                e1_guard
                pred
            in
            Env.add_assert kf cond pred;
            cond
          in
          Some e1_guard_cond, env
        else
          None, env
      in
      let mk_stmts _ e =
        let shift_instr = mk_shift_instr e in
        match e1_guard_opt with
        | None -> [ shift_instr ]
        | Some e1_guard -> [ e1_guard; shift_instr ]
      in
      let name = bop_name in
      let _, e, env = Env.new_var_and_mpz_init ~loc ~name env kf t mk_stmts in
      e, env, C_number, ""
    else begin
      assert (Logic_typing.is_integral_type t.term_type);
      Cil.new_exp ~loc (BinOp(bop, e1, e2, ty)), env, C_number, ""
    end
  | TBinOp(LOr, t1, t2) ->
    (* t1 || t2 <==> if t1 then true else t2 *)
    let e, env =
      Env.with_rte_and_result env true
        ~f:(fun env ->
            let e1, env1 = term_to_exp kf env t1 in
            let env' = Env.push env1 in
            let res2 = term_to_exp kf (Env.push env') t2 in
            conditional_to_exp
              ~name:"or" loc kf (Some t) e1 (Cil.one loc, env') res2
          )
    in
    e, env, C_number, ""
  | TBinOp(LAnd, t1, t2) ->
    (* t1 && t2 <==> if t1 then t2 else false *)
    let e, env =
      Env.with_rte_and_result env true
        ~f:(fun env ->
            let e1, env1 = term_to_exp kf env t1 in
            let _, env2 as res2 = term_to_exp kf (Env.push env1) t2 in
            let env3 = Env.push env2 in
            conditional_to_exp
              ~name:"and" loc kf (Some t) e1 res2 (Cil.zero loc, env3)
          )
    in
    e, env, C_number, ""
  | TBinOp((BOr | BXor | BAnd) as bop, t1, t2) ->
    (* other logic/arith operators  *)
    let ty = Typing.get_typ t in
    let e1, env = term_to_exp kf env t1 in
    let e2, env = term_to_exp kf env t2 in
    if Gmp_types.Z.is_t ty then
      let mk_stmts _v e =
        let name = name_of_mpz_arith_bop bop in
        let instr = Smart_stmt.rtl_call ~loc ~prefix:"" name [ e; e1; e2 ] in
        [ instr ]
      in
      let name = Misc.name_of_binop bop in
      let t = Some t in
      let _, e, env = Env.new_var_and_mpz_init ~loc ~name env kf t mk_stmts in
      e, env, C_number, ""
    else begin
      assert (Logic_typing.is_integral_type t.term_type);
      Cil.new_exp ~loc (BinOp(bop, e1, e2, ty)), env, C_number, ""
    end
  | TBinOp(PlusPI | IndexPI | MinusPI as bop, t1, t2) ->
    if Misc.is_set_of_ptr_or_array t1.term_type ||
       Misc.is_set_of_ptr_or_array t2.term_type then
      (* case of arithmetic over set of pointers (due to use of ranges)
         should have already been handled in [Memory_translate.call_with_ranges]
      *)
      assert false;
    (* binary operation over pointers *)
    let ty = match t1.term_type with
      | Ctype ty -> ty
      | _ -> assert false
    in
    let e1, env = term_to_exp kf env t1 in
    let e2, env = term_to_exp kf env t2 in
    Cil.new_exp ~loc (BinOp(bop, e1, e2, ty)), env, C_number, ""
  | TBinOp(MinusPP, t1, t2) ->
    begin match Typing.get_number_ty t with
      | Typing.C_integer _ ->
        let e1, env = term_to_exp kf env t1 in
        let e2, env = term_to_exp kf env t2 in
        let ty = Typing.get_typ t in
        Cil.new_exp ~loc (BinOp(MinusPP, e1, e2, ty)), env, C_number, ""
      | Typing.Gmpz ->
        Env.not_yet env "pointer subtraction resulting in gmp"
      | Typing.(C_float _ | Rational | Real | Nan) ->
        assert false
    end
  | TCastE(ty, t') ->
    let e, env = term_to_exp kf env t' in
    let e, env =
      add_cast ~loc ~name:"cast" env kf (Some ty) C_number (Some t) e
    in
    e, env, C_number, ""
  | TLogic_coerce _ -> assert false (* handle in [term_to_exp] *)
  | TAddrOf lv ->
    let lv, env, _ = tlval_to_lval kf env lv in
    Cil.mkAddrOf ~loc lv, env, C_number, "addrof"
  | TStartOf lv ->
    let lv, env, _ = tlval_to_lval kf env lv in
    Cil.mkAddrOrStartOf ~loc lv, env, C_number, "startof"
  | Tapp(li, [], targs) ->
    let fname = li.l_var_info.lv_name in
    (* build the varinfo (as an expression) which stores the result of the
       function call. *)
    let _, e, env =
      if Builtins.mem li.l_var_info.lv_name then
        (* E-ACSL built-in function call *)
        let args, env =
          try
            List.fold_right
              (fun targ (l, env) ->
                 let e, env = term_to_exp kf env targ in
                 e :: l, env)
              targs
              ([], env)
          with Invalid_argument _ ->
            Options.fatal
              "[Tapp] unexpected number of arguments when calling %s"
              fname
        in
        Env.new_var
          ~loc
          ~name:(fname ^ "_app")
          env
          kf
          (Some t)
          (Misc.cty (Option.get li.l_type))
          (fun vi _ ->
             [ Smart_stmt.rtl_call ~loc
                 ~result:(Cil.var vi)
                 ~prefix:""
                 fname
                 args ])
      else
        (* build the arguments and compute the integer_ty of the parameters *)
        let params_ty, args, env =
          List.fold_right
            (fun targ (params_ty, args, env) ->
               let e, env = term_to_exp kf env targ in
               let param_ty = Typing.get_number_ty targ in
               let e, env =
                 try
                   let ty = Typing.typ_of_number_ty param_ty in
                   add_cast loc env kf (Some ty) C_number (Some targ) e
                 with Typing.Not_a_number ->
                   e, env
               in
               param_ty :: params_ty, e :: args, env)
            targs
            ([], [], env)
        in
        let gen_fname =
          Varname.get ~scope:Varname.Global (Functions.RTL.mk_gen_name fname)
        in
        Logic_functions.tapp_to_exp ~loc gen_fname env kf t li params_ty args
    in
    e, env, C_number, "app"
  | Tapp(_, _ :: _, _) ->
    Env.not_yet env "logic functions with labels"
  | Tlambda _ -> Env.not_yet env "functional"
  | TDataCons _ -> Env.not_yet env "constructor"
  | Tif(t1, t2, t3) ->
    let e, env =
      Env.with_rte_and_result env true
        ~f:(fun env ->
            let e1, env1 = term_to_exp kf env t1 in
            let (_, env2 as res2) = term_to_exp kf (Env.push env1) t2 in
            let res3 = term_to_exp kf (Env.push env2) t3 in
            conditional_to_exp loc kf (Some t) e1 res2 res3
          )
    in
    e, env, C_number, ""
  | Tat(t, BuiltinLabel Here) ->
    let e, env = term_to_exp kf env t in
    e, env, C_number, ""
  | Tat(t', label) ->
    let lscope = Env.Logic_scope.get env in
    let pot = Lscope.PoT_term t' in
    if Lscope.is_used lscope pot then
      let e, env = At_with_lscope.to_exp ~loc kf env pot label in
      e, env, C_number, ""
    else
      let e, env = term_to_exp kf (Env.push env) t' in
      let e, env, sty = at_to_exp_no_lscope env kf (Some t) label e in
      e, env, sty, ""
  | Tbase_addr(BuiltinLabel Here, t) ->
    let name = "base_addr" in
    let e, env = Memory_translate.call ~loc kf name Cil.voidPtrType env t in
    e, env, C_number, name
  | Tbase_addr _ -> Env.not_yet env "labeled \\base_addr"
  | Toffset(BuiltinLabel Here, t) ->
    let size_t = Cil.theMachine.Cil.typeOfSizeOf in
    let name = "offset" in
    let e, env = Memory_translate.call ~loc kf name size_t env t in
    e, env, C_number, name
  | Toffset _ -> Env.not_yet env "labeled \\offset"
  | Tblock_length(BuiltinLabel Here, t) ->
    let size_t = Cil.theMachine.Cil.typeOfSizeOf in
    let name = "block_length" in
    let e, env = Memory_translate.call ~loc kf name size_t env t in
    e, env, C_number, name
  | Tblock_length _ -> Env.not_yet env "labeled \\block_length"
  | Tnull ->
    Cil.mkCast (TPtr(TVoid [], [])) (Cil.zero ~loc), env, C_number, "null"
  | TUpdate _ -> Env.not_yet env "functional update"
  | Ttypeof _ -> Env.not_yet env "typeof"
  | Ttype _ -> Env.not_yet env "C type"
  | Tempty_set -> Env.not_yet env "empty tset"
  | Tunion _ -> Env.not_yet env "union of tsets"
  | Tinter _ -> Env.not_yet env "intersection of tsets"
  | Tcomprehension _ -> Env.not_yet env "tset comprehension"
  | Trange _ -> Env.not_yet env "range"
  | Tlet(li, t) ->
    let lvs = Lscope.Lvs_let(li.l_var_info, Misc.term_of_li li) in
    let env = Env.Logic_scope.extend env lvs in
    let env = env_of_li li kf env loc in
    let e, env = term_to_exp kf env t in
    Interval.Env.remove li.l_var_info;
    e, env, C_number, ""

(* Convert an ACSL term into a corresponding C expression (if any) in the given
   environment. Also extend this environment in order to include the generating
   constructs. *)
and term_to_exp kf env t =
  let generate_rte = Env.generate_rte env in
  Options.feedback ~dkey ~level:4 "translating term %a (rte? %b)"
    Printer.pp_term t generate_rte;
  Env.with_rte_and_result env false
    ~f:(fun env ->
        let t = match t.term_node with TLogic_coerce(_, t) -> t | _ -> t in
        let e, env, sty, name = context_insensitive_term_to_exp kf env t in
        let env = if generate_rte then translate_rte kf env e else env in
        let cast = Typing.get_cast t in
        let name = if name = "" then None else Some name in
        add_cast
          ~loc:t.term_loc
          ?name
          env
          kf
          cast
          sty
          (Some t)
          e
      )

(* generate the C code equivalent to [t1 bop t2]. *)
and comparison_to_exp
    ~loc ?e1 kf env ity bop ?(name = Misc.name_of_binop bop) t1 t2 t_opt =
  let e1, env = match e1 with
    | None ->
      let e1, env = term_to_exp kf env t1 in
      e1, env
    | Some e1 ->
      e1, env
  in
  let ty1 = Cil.typeOf e1 in
  let e2, env = term_to_exp kf env t2 in
  let ty2 = Cil.typeOf e2 in
  match Logic_aggr.get_t ty1, Logic_aggr.get_t ty2 with
  | Logic_aggr.Array, Logic_aggr.Array ->
    Logic_array.comparison_to_exp
      ~loc
      kf
      env
      ~name
      bop
      e1
      e2
  | Logic_aggr.StructOrUnion, Logic_aggr.StructOrUnion ->
    Env.not_yet env "comparison between two structs or unions"
  | Logic_aggr.NotAggregate, Logic_aggr.NotAggregate -> begin
      match ity with
      | Typing.C_integer _ | Typing.C_float _ | Typing.Nan ->
        Cil.mkBinOp ~loc bop e1 e2, env
      | Typing.Gmpz ->
        let _, e, env = Env.new_var
            ~loc
            env
            kf
            t_opt
            ~name
            Cil.intType
            (fun v _ ->
               [ Smart_stmt.rtl_call ~loc
                   ~result:(Cil.var v)
                   ~prefix:""
                   "__gmpz_cmp"
                   [ e1; e2 ] ])
        in
        Cil.new_exp ~loc (BinOp(bop, e, Cil.zero ~loc, Cil.intType)), env
      | Typing.Rational ->
        Rational.cmp ~loc bop e1 e2 env kf t_opt
      | Typing.Real ->
        Error.not_yet "comparison involving real numbers"
    end
  | _, _ ->
    Options.fatal
      ~current:true
      "Comparison involving incompatible types: '%a' and '%a'"
      Printer.pp_typ ty1
      Printer.pp_typ ty2

and at_to_exp_no_lscope env kf t_opt label e =
  let stmt = E_acsl_label.get_stmt kf label in
  (* generate a new variable denoting [\at(t',label)].
     That is this variable which is the resulting expression.
     ACSL typing rule ensures that the type of this variable is the same as
     the one of [e]. *)
  let loc = Stmt.loc stmt in
  let res_v, res, new_env =
    Env.new_var
      ~loc
      ~name:"at"
      ~scope:Varname.Function
      env
      kf
      t_opt
      (Cil.typeOf e)
      (fun _ _ -> [])
  in
  let env_ref = ref new_env in
  (* visitor modifying in place the labeled statement in order to store [e]
     in the resulting variable at this location (which is the only correct
     one). *)
  let o = object
    inherit Visitor.frama_c_inplace
    method !vstmt_aux stmt =
      (* either a standard C affectation or a call to an initializer according
         to the type of [e] *)
      let ty = Cil.typeOf e in
      let init_set =
        if Gmp_types.Q.is_t ty then Rational.init_set else Gmp.init_set
      in
      let new_stmt = init_set ~loc (Cil.var res_v) res e in
      assert (!env_ref == new_env);
      (* generate the new block of code for the labeled statement and the
         corresponding environment *)
      let block, new_env =
        Env.pop_and_get new_env new_stmt ~global_clear:false Env.Middle
      in
      env_ref := Env.extend_stmt_in_place new_env stmt ~label block;
      Cil.ChangeTo stmt
  end
  in
  ignore (Visitor.visitFramacStmt o stmt);
  res, !env_ref, C_number

and env_of_li li kf env loc =
  let t = Misc.term_of_li li in
  let ty = Typing.get_typ t in
  let vi, vi_e, env = Env.Logic_binding.add ~ty env kf li.l_var_info in
  let e, env = term_to_exp kf env t in
  let stmt = match Typing.get_number_ty t with
    | Typing.(C_integer _ | C_float _ | Nan) ->
      Smart_stmt.assigns ~loc ~result:(Cil.var vi) e
    | Typing.Gmpz ->
      Gmp.init_set ~loc (Cil.var vi) vi_e e
    | Typing.Rational ->
      Rational.init_set ~loc (Cil.var vi) vi_e e
    | Typing.Real ->
      Error.not_yet "real number"
  in
  Env.add_stmt env kf stmt

(* Convert an ACSL predicate into a corresponding C expression (if any) in the
   given environment. Also extend this environment which includes the generating
   constructs. *)
and predicate_content_to_exp ?name kf env p =
  let loc = p.pred_loc in
  match p.pred_content with
  | Pfalse -> Cil.zero ~loc, env
  | Ptrue -> Cil.one ~loc, env
  | Papp(li, labels, args) ->
    (* Simply use the implementation of Tapp(li, labels, args).
       To achieve this, we create a clone of [li] for which the type is
       transformed from [None] (type of predicates) to
       [Some int] (type as a term). *)
    let prj = Project.current () in
    let o = object inherit Visitor.frama_c_copy prj end in
    let li = Visitor.visitFramacLogicInfo o li in
    let lty = Ctype Cil.intType in
    li.l_type <- Some lty;
    let tapp = Logic_const.term ~loc (Tapp(li, labels, args)) lty in
    Typing.type_term ~use_gmp_opt:false ~ctx:Typing.c_int tapp;
    let e, env = term_to_exp kf env tapp in
    e, env
  | Pdangling _ -> Env.not_yet env "\\dangling"
  | Pobject_pointer _ -> Env.not_yet env "\\object_pointer"
  | Pvalid_function _ -> Env.not_yet env "\\valid_function"
  | Prel(rel, t1, t2) ->
    let ity = Typing.get_integer_op_of_predicate p in
    comparison_to_exp ~loc kf env ity (relation_to_binop rel) t1 t2 None
  | Pand(p1, p2) ->
    (* p1 && p2 <==> if p1 then p2 else false *)
    Env.with_rte_and_result env true
      ~f:(fun env ->
          let e1, env1 = predicate_to_exp kf env p1 in
          let _, env2 as res2 =
            predicate_to_exp kf (Env.push env1) p2 in
          let env3 = Env.push env2 in
          let name = match name with None -> "and" | Some n -> n in
          conditional_to_exp ~name loc kf None e1 res2 (Cil.zero loc, env3)
        )
  | Por(p1, p2) ->
    (* p1 || p2 <==> if p1 then true else p2 *)
    Env.with_rte_and_result env true
      ~f:(fun env ->
          let e1, env1 = predicate_to_exp kf env p1 in
          let env' = Env.push env1 in
          let res2 = predicate_to_exp kf (Env.push env') p2 in
          let name = match name with None -> "or" | Some n -> n in
          conditional_to_exp ~name loc kf None e1 (Cil.one loc, env') res2
        )
  | Pxor _ -> Env.not_yet env "xor"
  | Pimplies(p1, p2) ->
    (* (p1 ==> p2) <==> !p1 || p2 *)
    predicate_to_exp
      ~name:"implies"
      kf
      env
      (Logic_const.por ~loc ((Logic_const.pnot ~loc p1), p2))
  | Piff(p1, p2) ->
    (* (p1 <==> p2) <==> (p1 ==> p2 && p2 ==> p1) *)
    predicate_to_exp
      ~name:"equiv"
      kf
      env
      (Logic_const.pand ~loc
         (Logic_const.pimplies ~loc (p1, p2),
          Logic_const.pimplies ~loc (p2, p1)))
  | Pnot p ->
    let e, env = predicate_to_exp kf env p in
    Cil.new_exp ~loc (UnOp(LNot, e, Cil.intType)), env
  | Pif(t, p2, p3) ->
    Env.with_rte_and_result env true
      ~f:(fun env ->
          let e1, env1 = term_to_exp kf env t in
          let (_, env2 as res2) =
            predicate_to_exp kf (Env.push env1) p2 in
          let res3 = predicate_to_exp kf (Env.push env2) p3 in
          conditional_to_exp loc kf None e1 res2 res3
        )
  | Plet(li, p) ->
    let lvs = Lscope.Lvs_let(li.l_var_info, Misc.term_of_li li) in
    let env = Env.Logic_scope.extend env lvs in
    let env = env_of_li li kf env loc in
    let e, env = predicate_to_exp kf env p in
    Interval.Env.remove li.l_var_info;
    e, env
  | Pforall _ | Pexists _ -> Quantif.quantif_to_exp kf env p
  | Pat(p, BuiltinLabel Here) ->
    predicate_to_exp kf env p
  | Pat(p', label) ->
    let lscope = Env.Logic_scope.get env in
    let pot = Lscope.PoT_pred p' in
    if Lscope.is_used lscope pot then
      At_with_lscope.to_exp ~loc kf env pot label
    else begin
      (* convert [t'] to [e] in a separated local env *)
      let e, env = predicate_to_exp kf (Env.push env) p' in
      let e, env, sty = at_to_exp_no_lscope env kf None label e in
      assert (sty = C_number);
      e, env
    end
  | Pvalid_read(BuiltinLabel Here as llabel, t) as pc
  | (Pvalid(BuiltinLabel Here as llabel, t) as pc) ->
    let call_valid t =
      let name = match pc with
        | Pvalid _ -> "valid"
        | Pvalid_read _ -> "valid_read"
        | _ -> assert false
      in
      Memory_translate.call_valid ~loc kf name Cil.intType env t
    in
    if !is_visiting_valid then begin
      (* we already transformed \valid(t) into \initialized(&t) && \valid(t):
         now convert this right-most valid. *)
      is_visiting_valid := false;
      call_valid t p
    end else begin
      match t.term_node, t.term_type with
      | TLval tlv, Ctype ty ->
        let init =
          Logic_const.pinitialized ~loc (llabel, Misc.term_addr_of ~loc tlv ty)
        in
        Typing.type_named_predicate ~must_clear:false init;
        let p = Logic_const.pand ~loc (init, p) in
        is_visiting_valid := true;
        predicate_to_exp kf env p
      | _ ->
        call_valid t p
    end
  | Pvalid _ -> Env.not_yet env "labeled \\valid"
  | Pvalid_read _ -> Env.not_yet env "labeled \\valid_read"
  | Pseparated tlist ->
    let env =
      List.fold_left
        (fun env t ->
           let name = "separated_guard" in
           let p = Logic_const.pvalid_read ~loc (BuiltinLabel Here, t) in
           let p = { p with pred_name = name :: p.pred_name } in
           let e, env =
             predicate_content_to_exp
               ~name
               kf
               env
               p
           in
           let stmt =
             Smart_stmt.runtime_check
               Smart_stmt.RTE
               kf
               e
               p
           in
           Env.add_assert kf stmt p;
           Env.add_stmt env kf stmt
        )
        env
        tlist
    in
    Memory_translate.call_with_size ~loc kf "separated" Cil.intType env tlist p
  | Pinitialized(BuiltinLabel Here, t) ->
    (match t.term_node with
     (* optimisation when we know that the initialisation is ok *)
     | TAddrOf (TResult _, TNoOffset) -> Cil.one ~loc, env
     | TAddrOf (TVar { lv_origin = Some vi }, TNoOffset)
       when
         vi.vformal || vi.vglob || Functions.RTL.is_generated_name vi.vname ->
       Cil.one ~loc, env
     | _ ->
       Memory_translate.call_with_size
         ~loc
         kf
         "initialized"
         Cil.intType
         env
         [ t ]
         p)
  | Pinitialized _ -> Env.not_yet env "labeled \\initialized"
  | Pallocable _ -> Env.not_yet env "\\allocate"
  | Pfreeable(BuiltinLabel Here, t) ->
    Memory_translate.call ~loc kf "freeable" Cil.intType env t
  | Pfreeable _ -> Env.not_yet env "labeled \\freeable"
  | Pfresh _ -> Env.not_yet env "\\fresh"

and predicate_to_exp ?name kf ?rte env p =
  let rte = match rte with None -> Env.generate_rte env | Some b -> b in
  Env.with_rte_and_result env false
    ~f:(fun env ->
        let e, env = predicate_content_to_exp ?name kf env p in
        let env = if rte then translate_rte kf env e else env in
        let cast = Typing.get_cast_of_predicate p in
        add_cast
          ~loc:p.pred_loc
          ?name
          env
          kf
          cast
          C_number
          None
          e
      )

and generalized_untyped_predicate_to_exp ?name kf ?rte ?must_clear_typing env p =
  (* If [rte] is true, it means we're translating the root predicate of an
     assertion and we need to generate the RTE for it. The typing environment
     must be cleared. Otherwise, if [rte] is false, it means we're already
     translating RTE predicates as part of the translation of another root
     predicate, and the typing environment must be kept. *)
  let rte = match rte with None -> Env.generate_rte env | Some b -> b in
  let must_clear = match must_clear_typing with None -> rte | Some b -> b in
  Typing.type_named_predicate ~must_clear p;
  let e, env = predicate_to_exp ?name kf ~rte env p in
  assert (Typ.equal (Cil.typeOf e) Cil.intType);
  let env = Env.Logic_scope.reset env in
  e, env

and translate_rte_annots:
  'a. (Format.formatter -> 'a -> unit) -> 'a ->
  kernel_function -> Env.t -> code_annotation list -> Env.t =
  fun pp elt kf env l ->
  let old_valid = !is_visiting_valid in
  let old_kind = Env.annotation_kind env in
  let env = Env.set_annotation_kind env Smart_stmt.RTE in
  let env =
    List.fold_left
      (fun env a -> match a.annot_content with
         | AAssert(_, p) ->
           Env.handle_error
             (fun env ->
                Options.feedback ~dkey ~level:4 "prevent RTE from %a" pp elt;
                (* The logic scope MUST NOT be reset here since we still might
                   be in the middle of the translation of the original
                   predicate. *)
                let lscope_reset_old = Env.Logic_scope.get_reset env in
                let env = Env.Logic_scope.set_reset env false in
                let env =
                  Env.with_rte env false
                    ~f:(fun env -> translate_predicate kf env p)
                in
                let env = Env.Logic_scope.set_reset env lscope_reset_old in
                env)
             env
         | _ -> assert false)
      env
      l
  in
  is_visiting_valid := old_valid;
  Env.set_annotation_kind env old_kind

and translate_rte ?filter kf env e =
  let stmt = Cil.mkStmtOneInstr ~valid_sid:true (Skip e.eloc) in
  let l = Rte.exp kf stmt e in
  let l =
    match filter with
    | Some f -> List.filter f l
    | None -> l
  in
  translate_rte_annots Printer.pp_exp e kf env l

and translate_predicate ?pred_to_print kf env p =
  Options.feedback ~dkey ~level:3 "translating predicate %a"
    Printer.pp_toplevel_predicate p;
  let pred_to_print =
    match pred_to_print with
    | Some pred ->
      Options.feedback ~dkey ~level:3 "(predicate to print %a)"
        Printer.pp_predicate pred;
      pred
    | None -> p.tp_statement
  in
  let e, env = generalized_untyped_predicate_to_exp kf env p.tp_statement in
  Env.add_stmt
    env
    kf
    (Smart_stmt.runtime_check
       (Env.annotation_kind env)
       kf
       e
       pred_to_print)

let predicate_to_exp_without_rte ?name kf env p =
  predicate_to_exp ?name kf env p (* forget optional argument ?rte *)

let () =
  Loops.term_to_exp_ref := term_to_exp;
  Loops.translate_predicate_ref := translate_predicate;
  Loops.predicate_to_exp_ref := predicate_to_exp_without_rte;
  Quantif.predicate_to_exp_ref := predicate_to_exp_without_rte;
  At_with_lscope.term_to_exp_ref := term_to_exp;
  At_with_lscope.predicate_to_exp_ref := predicate_to_exp_without_rte;
  Memory_translate.term_to_exp_ref := term_to_exp;
  Memory_translate.predicate_to_exp_ref := predicate_to_exp_without_rte;
  Logic_functions.term_to_exp_ref := term_to_exp;
  Logic_functions.predicate_to_exp_ref := predicate_to_exp_without_rte;
  Logic_array.translate_rte_ref := translate_rte

exception No_simple_term_translation of term
exception No_simple_predicate_translation of predicate

(* This function is used by Guillaume.
   However, it is correct to use it only in specific contexts. *)
let untyped_predicate_to_exp p =
  let env = Env.push Env.empty in
  let env = Env.rte env false in
  let e, env =
    try generalized_untyped_predicate_to_exp ~must_clear_typing:false (Kernel_function.dummy ()) env p
    with Rtl.Symbols.Unregistered _ -> raise (No_simple_predicate_translation p)
  in
  if not (Env.has_no_new_stmt env) then raise (No_simple_predicate_translation p);
  e

(* This function is used by plug-in [Cfp]. *)
let untyped_term_to_exp typ t =
  (* infer a context from the given [typ] whenever possible *)
  let ctx_of_typ ty =
    if Gmp_types.Z.is_t ty then Typing.gmpz
    else if Gmp_types.Q.is_t ty then Typing.rational
    else
      match ty with
      | TInt(ik, _) | TEnum({ ekind = ik }, _) -> Typing.ikind ik
      | TFloat(fk, _) -> Typing.fkind fk
      | _ -> Typing.nan
  in
  let ctx = Option.map ctx_of_typ typ in
  Typing.type_term ~use_gmp_opt:true ?ctx t;
  let env = Env.push Env.empty in
  let env = Env.rte env false in
  let e, env =
    try term_to_exp (Kernel_function.dummy ()) env t
    with Rtl.Symbols.Unregistered _ -> raise (No_simple_term_translation t)
  in
  if not (Env.has_no_new_stmt env) then raise (No_simple_term_translation t);
  e

(*
Local Variables:
compile-command: "make -C ../../../../.."
End:
*)
