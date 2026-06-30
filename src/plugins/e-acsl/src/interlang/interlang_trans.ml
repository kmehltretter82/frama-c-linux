(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(* The new compilation scheme of E-ACSL to Cil is implemented as a two-stage
   process, where E-ACSL is first translated into an intermediate language
   Interlang and only then into Cil. This module implements the second stage.
   To this end we define here a monad M for specifying computations that
   generate Cil expressions, and that while doing so modifies the assertion
   data (of type Assert.t) and the environment (of type Env.t). *)

open Interlang

let dkey = Options.Dkey.interlang_translation

module Conf = struct
  (* The Reader variable of M. See Monad_rws.Conf.env *)
  type env = {kf : Cil_types.kernel_function;
              loc : Fileloc.t;
              adata_register : bool;
              rtes : rte list}

  (* The State variable of M. The monad generates Cil expressions, all the
     while making modifications to the current environment (of type Env.t) and
     the recorded assertion data (of type Assert.t). *)
  type state = {env : Env.t; adata : Assert.t}

  (** The out variable of {!M} contains a [bool] which specifies if the RTE list
      of the current expression has been compiled during its compilation or
      if it needs to be compiled after its compilation. *)
  type out = bool (* The Writer variable of M. *)
  let merge_out o1 o2 = o1 || o2
  let empty_out () = false
end

(** The intermediate language translation monad. It is used for translating
    expressions of the E-ACSL intermediate language (see {!Interlang}) to Cil. *)
module M = struct
  include Monad_rws.Make (Conf)
  open Operators

  let modify_adata f = modify (fun s -> {s with adata = f s.adata})

  let without_registering_adata m =
    with_env (fun env -> {env with adata_register = false}) m

  let with_rtes rtes m =
    with_env (fun env -> {env with rtes = rtes}) m

  let with_loc loc m = with_env (fun env -> {env with loc}) m

  let do_if_registering_adata m =
    let* env = read in
    if env.adata_register then m else return ()

  let modifying_env f =
    let* {env} as state = get in
    let e, env = f env in
    let* () = set {state with env} in
    return e

  let push_env a = modifying_env @@ fun env -> a, Env.push env

  let with_generating_adata m =
    Assert.push_pending_register_data ();
    let* res = m in
    modifying_env @@ fun env ->
    res, Assert.do_pending_register_data env
end

open M.Operators

let compile_unop = function
  | Interlang.Neg -> Cil_types.Neg
  | Interlang.Not -> LNot

let compile_binop = function
  | Interlang.Plus -> Cil_types.PlusA
  | Minus -> MinusA
  | Mult -> Mult
  | Div -> Div
  | Mod -> Mod
  | Lt -> Lt
  | Gt -> Gt
  | Le -> Le
  | Ge -> Ge
  | Eq -> Eq
  | Ne -> Ne
  | And -> LAnd
  | Or -> LOr

let assert_register_term ~loc ?force e t =
  M.do_if_registering_adata @@
  M.modify_adata @@ fun a ->
  Assert.register_term ~loc ?force t e a

let rec compile exp =
  let* e, coerce, cast_info = compile_with_rtes exp in
  match cast_info with (* [cast_info] specifies type type we cast from. *)
  | Some (strnum, name) ->
    let name = if name = "" then None else Some name in
    let* {kf} = M.read in
    let loc = Misc.get_loc_from_pot exp.origin in
    M.modifying_env (fun env ->
        Typed_number.add_cast ~loc
          ?name
          env
          kf
          coerce
          strnum
          (Misc.get_term_from_pot exp.origin)
          e)
  | None -> M.return e (* no cast required *)

and compile_with_rtes exp =
  let cil = M.with_rtes exp.rtes @@ compile_context_insensitive exp in
  let* (cil,early) = M.flush cil in
  let+ () =
    if not early then M.List.iter compile_rte_guard exp.rtes else M.return ()
  in
  cil

(** [let* () = force_rtes () in] forces the early compilation of the
    current environment's RTEs. This can be used if for instance the
    compilation of a term will produce intermediary computations and
    we want to compile RTEs before those intermediary computations. *)
and force_rtes () =
  let* {rtes} = M.read in
  M.update true @@ M.List.iter compile_rte_guard rtes

and compile_conditional ~ity ~origin ?(name = "if") op1 op2 op3 =
  let* {kf; loc} = M.read in
  let ty = Typing.typ_of_number_ty ity in
  let* e1 = M.with_generating_adata @@ compile op1 in
  let* () = M.push_env () in
  let* e2 = M.with_generating_adata @@ compile op2 in
  let* {env = env2} = M.get in
  let* () = M.push_env () in
  let* e3 = M.with_generating_adata @@ compile op3 in
  let* {env = env3} = M.get in
  M.modifying_env @@ fun env ->
  let env = Env.pop (Env.pop env) in
  let _, e, env =
    Env.new_var
      ~loc
      ~name
      env
      kf
      (Misc.get_term_from_pot origin) (* /!\ Use the term for optimization *)
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
           Env.pop_and_get ~kf env2 s ~global_clear:false Env.Middle
         in
         let else_blk, _ =
           let s = affect e3 in
           Env.pop_and_get ~kf env3 s ~global_clear:false Env.Middle
         in
         [ Smart_stmt.if_stmt ~loc ~cond:e1 then_blk ~else_blk ])
  in e, env

and compile_context_insensitive {Interlang.enode; origin} =
  let* {kf; loc} = M.read in
  match enode with
  | Integer {n; ity} ->
    (* cf Translate_terms.constant_to_exp *)
    let e, strnum =
      let open Analyses_types in
      match ity with
      | Nan -> assert false
      | Real -> Error.not_yet "real number constant"
      | Rational ->
        let s = Gmp.Q.normalize_str (Z.to_string n) in
        let vi = Globals.Vars.add_string_literal ~loc @@ Str s in
        Cil.mkAddrOrStartOf ~loc (Cil.var vi), Str_R
      | Gmpz ->
        let vi = Globals.Vars.add_string_literal ~loc @@ Str (Z.to_string n) in
        Cil.mkAddrOrStartOf ~loc (Cil.var vi), Str_Z
      | C_float fkind ->
        Cil.kfloat ~loc fkind (Int64.to_float (Z.to_int64 n)), C_number
      | C_integer kind ->
        (* do not keep the initial string representation because the generated
           constant must reflect its type computed by the type system. For
           instance, when translating [INT_MAX+1], we must generate a [long
           long] addition and so [1LL]. If we keep the initial string
           representation, the kind would be ignored in the generated code and
           so [1] would be generated. *)
        Cil.kinteger64 ~loc ~kind n, C_number
    in
    M.return (e, None, Some (strnum, ""))
  | BinOp {ity; binop = Lt | Gt | Le | Ge | Eq | Ne as binop; op1; op2} ->
    let binop = compile_binop binop in
    let* e1 = compile op1 in
    let* e2 = compile op2 in
    let name = Misc.name_of_binop binop in
    let* e = M.modifying_env @@ fun env -> Translate_utils.comparison_to_exp
        ~loc
        kf
        env
        ity
        binop
        e1
        e2
        ~name
        (Misc.get_term_from_pot origin)
    in
    M.return (e, None, Some (Analyses_types.C_number, name))
  | UnOp {ity; unop = Neg as uop; op} ->
    let unop = compile_unop uop in
    let* e = compile op in
    begin match ity with
      | Gmpz ->
        let* () = force_rtes () in
        let+ e = M.modifying_env @@ fun env ->
          Gmp.Z.new_var
            ~loc
            env
            kf
            ~name:"neg"
            (Misc.get_term_from_pot origin)
            (fun _ ev ->
               [ Smart_stmt.rtl_call ~loc ~prefix:"" "__gmpz_neg" [ ev; e ] ])
        in
        e, None, Some (Analyses_types.C_number, Misc.name_of_unop unop)
      | Rational ->
        let* {env} = M.get in
        Env.not_yet env "reals: Neg"
      | _ ->
        let ty = Typing.typ_of_number_ty ity in
        let e = Cil.new_exp ~loc (UnOp(unop, e, ty)) in
        M.return (e, None, Some (Analyses_types.C_number, ""))
    end
  | UnOp {unop = Not; op} ->
    let* e = compile op in
    M.return (Smart_exp.lnot ~loc e, None, Some (Analyses_types.C_number, ""))
  | BinOp {ity; binop = Plus | Minus | Mult | Div | Mod as binop; op1; op2} ->
    let binop = compile_binop binop in
    let origin = Misc.get_term_from_pot origin in
    let* e1 = compile op1 in
    let* e2 = compile op2 in
    let* e = match ity with
      | Gmpz ->
        let* () = force_rtes () in
        M.modifying_env @@ fun env ->
        Gmp.Z.binop ~loc origin binop env kf e1 e2
      | Rational ->
        let* () = force_rtes () in
        M.modifying_env @@ fun env ->
        Gmp.Q.binop ~loc origin binop env kf e1 e2
      | Analyses_types.C_integer _
      | Analyses_types.C_float _
      | Analyses_types.Real
      | Analyses_types.Nan ->
        let ty = Typing.typ_of_number_ty ity in
        M.return @@ Cil.new_exp ~loc @@ BinOp (binop, e1, e2, ty)
    in
    M.return (e, None, Some (Analyses_types.C_number, Misc.name_of_binop binop))
  | BinOp {ity; binop = And; op1; op2} ->
    let name = match origin with
      | Analyses_types.PoT_pred { pred_content = Piff _ } -> "equiv"
      | _ -> "and"
    in
    let* e = compile_conditional
        ~ity
        ~origin
        ~name
        op1
        op2
        (Interlang.Exp.mk_false ~origin ())
    in
    M.return (e, None, Some (Analyses_types.C_number, ""))
  | BinOp {ity; binop = Or; op1; op2} ->
    let name = match origin with
      | Analyses_types.PoT_pred { pred_content = Pimplies _ } -> "implies"
      | _ -> "or"
    in
    let* e = compile_conditional
        ~ity
        ~origin
        ~name
        op1
        (Interlang.Exp.mk_true ~origin ())
        op2
    in
    M.return (e, None, Some (Analyses_types.C_number, ""))

  | If {ity; op1; op2; op3} ->
    let* e = compile_conditional ~ity ~origin op1 op2 op3 in
    M.return (e, None, Some (Analyses_types.C_number, ""))
  | Lval lval ->
    M.with_loc (Misc.get_loc_from_pot origin) @@
    let* lval, name = M.without_registering_adata @@ compile_lval lval in
    let* {loc} = M.read in
    let e = Smart_exp.lval ~loc lval in
    let* () =
      M.Option.iter
        (assert_register_term ~loc e)
        (Misc.get_term_from_pot origin)
    in
    M.return (e, None, Some (Analyses_types.C_number, name))
  | SizeOf ty ->
    let e = Cil.sizeOf ~loc ty in
    let* () =
      M.Option.iter
        (assert_register_term ~loc ~force:true e)
        (Misc.get_term_from_pot origin)
    in
    M.return (e, None, Some (Analyses_types.C_number, "sizeof"))
  | Coerce {coerce_to = typ; coerced = exp} ->
    let* e, coerce, cast_info = compile_with_rtes exp in
    ignore coerce; (* coerce to A and then B ⇒ just coerce directly to B *)
    M.return (e, Some typ, cast_info)
  | Bottom InductiveIncompleteFallthrough ->
    let e = Cil.zero ~loc in
    let* () = M.modify @@ fun {adata; env} ->
      let annot_kind = Env.annotation_kind env in
      let stmt, env =
        Assert.runtime_check_with_msg
          ~adata
          ~loc
          "Incomplete inductive function"
          ~pred_kind:Assert
          annot_kind
          kf
          env
          e
      in
      let env = Env.add_stmt env stmt in
      {env; adata = Assert.register_pred_or_term ~loc env origin e adata}
    in
    M.return (e, None, Some (Analyses_types.C_number, ""))

and compile_lhost = function
  | Var vi -> M.return (Cil_types.Var vi, vi.vorig_name)
  | Mem exp ->
    let* exp = M.without_registering_adata @@ compile exp in
    M.return (Cil_types.Mem exp, "")

and compile_offset = function
  | NoOffset -> M.return @@ Cil_types.NoOffset
  | Field (fieldinfo, offset) ->
    let* offset = compile_offset offset in
    M.return @@ Cil_types.Field (fieldinfo, offset)
  | Index (e, offset) ->
    let* e = M.without_registering_adata @@ compile e in
    let* offset = M.without_registering_adata @@ compile_offset offset in
    M.return @@ Cil_types.Index (e, offset)

and compile_lval (host, offset) =
  let* host, name = compile_lhost host in
  let* offset = compile_offset offset in
  M.return ((host, offset), name)

and compile_rte_guard rte =
  let* ({loc; kf}) = M.read in
  let* orig_state = M.get in
  let* () = M.modify @@ fun { env } ->
    Assert.push_pending_register_data ();
    let adata, env = Assert.empty ~loc kf env in
    Conf.{adata; env}
  in
  let* cil = compile @@ Interlang.Exp.rte rte in
  M.modify @@ fun {adata;env} ->
  let stmt, env =
    Assert.runtime_check
      ~adata
      ~pred_kind:Assert
      RTE
      kf
      env
      cil
      rte.rorigin
  in
  let env = Assert.do_pending_register_data env in
  let env = Env.add_stmt ~annot:rte.rorigin env stmt in
  {orig_state with env}

let generate_and_compile ~loc ~adata ~env ~kf m source =
  let interlang, _, _ =
    let env = Interlang_gen.{kf; loc; env; rte = true;
                             vars = Cil_datatype.Term.Map.empty} in
    let state = Cil_datatype.Term.Map.empty (* local variables *) in
    Interlang_gen.M.run ~env ~state @@ m source
  in
  Options.debug ~dkey ~level:3
    "@[interlang:@ @[%a@]@]" Interlang.Pretty.pp_exp interlang;
  let cil, _, Conf.{env; adata} =
    M.run
      ~env:{Conf.kf; loc; adata_register = true; rtes = interlang.rtes}
      ~state:Conf.{env; adata} @@
    compile interlang
  in
  Options.debug ~dkey ~level:4
    "@[Cil output:@ @[%a@]@]" Printer.pp_exp cil;
  cil, adata, env

let try_interlang il old =
  try if Options.Interlang.get () || Options.Interlang_force.get ()
    then il ()
    else old ()
  with Interlang_gen.Not_covered ->
    if Options.Interlang_force.get ()
    then Options.fatal
        "encountered construct unsupported by indirect compilation scheme;\
         run with \"-e-acsl-msg-key interlang:not_covered\" for details."
    else old ()

type 'a il_compiler = 'a -> Interlang.exp Interlang_gen.m

type 'a compiler =
  loc:Fileloc.t ->
  adata:Assert.t ->
  env:Env.t ->
  kf:Cil_types.kernel_function ->
  'a ->
  Cil_types.exp * Assert.t * Env.t

let try_il_compiler il old ~loc ~adata ~env ~kf x =
  try_interlang
    (fun () -> generate_and_compile ~loc ~adata ~env ~kf il x)
    (fun () -> old ~loc ~adata ~env ~kf x)
