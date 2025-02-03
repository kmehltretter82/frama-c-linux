(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2025                                               *)
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

(* The new compilation scheme of E-ACSL to Cil is implemented as a two-stage
   process, where E-ACSL is first translated into an intermediate language
   Interlang and only then into Cil. This module implements the second stage.
   To this end we define here a monad M for specifying computations that
   generate Cil expressions, and that while doing so modifies the assertion
   data (of type Assert.t) and the environment (of type Env.t). *)

open Interlang

module Conf = struct
  (* The Reader variable of M. See Monad_rws.Conf.env *)
  type env = {kf : Cil_types.kernel_function;
              loc : Cil_types.location;
              adata_register : bool}

  (* The State variable of M. The monad generates Cil expressions, all the
     while making modifications to the current environment (of type Env.t) and
     the recorded assertion data (of type Assert.t). *)
  type state = {env : Env.t; adata : Assert.t}

  type out = unit (* The Writer variable of M. *)
  let merge_out () () = ()
  let empty_out () = ()
end

(** The intermediate language translation monad. It is used for translating
    expressions of the E-ACSL intermediate language (see {!Interlang}) to Cil. *)
module M = struct
  include Monad_rws.Make (Conf)
  open Operators

  let modify_adata f = modify (fun s -> {s with adata = f s.adata})

  let without_registering_adata m =
    with_env (fun env -> {env with adata_register = false}) m

  let with_loc loc m = with_env (fun env -> {env with loc}) m
  let maybe_with_term_loc t_opt m =
    match t_opt with | None -> m | Some t -> with_loc t.Cil_types.term_loc m

  let do_if_registering_adata m =
    let* env = read in
    Bool.only_if env.adata_register m

  let get_logic_env = let* {env} = get in return @@ Env.Logic_env.get env

  let modifying_env f =
    let* {env} as state = get in
    let e, env = f env in
    let* () = set {state with env} in
    return e
end

open M.Operators

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

let assert_register_term ~loc ?force e t =
  M.do_if_registering_adata @@
  M.modify_adata @@ fun a ->
  Assert.register_term ~loc ?force t e a

let rec compile ({origin} as exp) =
  let* e, cast_info = compile_context_insensitive exp in
  match cast_info, origin with
  (* The type of [cast_info] specifies what we cast from. *)
  (* The type of the original term [origin] determines what we cast to. *)
  | Some (strnum, name), Some t ->
    let* logic_env = M.get_logic_env in
    let cast = Typing.get_cast ~logic_env t in
    let name = if name = "" then None else Some name in
    let* {kf} = M.read in
    M.modifying_env (fun env ->
        Typed_number.add_cast ~loc:t.term_loc ?name env kf cast strnum (Some t) e)
  | Some _, None (* [origin] is [None] when it stems from predicates. *)
  | None, None -> M.return e (* no cast required *)
  | None, Some _ -> Options.fatal "source information missing for cast"

and compile_context_insensitive {Interlang.enode; origin} =
  let* {kf; loc} = M.read in
  match enode with
  | True -> M.return (Cil.one ~loc, None)
  | False -> M.return (Cil.zero ~loc, None)
  | Integer n ->
    (* cf Translate_terms.constant_to_exp *)
    let origin = match origin with
      | Some o -> o
      | None -> Options.fatal "Integer is expected to have an associated origin"
    in
    let* logic_env = M.get_logic_env in
    let ity = Typing.get_number_ty ~logic_env origin in
    let cast = Typing.get_cast ~logic_env origin in
    let mk_real s =
      let s = Gmp.Q.normalize_str s in
      Cil.mkString ~loc s
    in
    let e, strnum =
      let open Analyses_types in
      match ity with
      | Nan -> assert false
      | Real -> Error.not_yet "real number constant"
      | Rational -> mk_real (Integer.to_string n), Str_R
      | Gmpz -> Cil.mkString ~loc (Integer.to_string n), Str_Z
      | C_float fkind ->
        Cil.kfloat ~loc fkind (Int64.to_float (Integer.to_int64_exn n)), C_number
      | C_integer kind ->
        match cast, kind with
        | Some ty, (ILongLong | IULongLong) when Gmp_types.Z.is_t ty ->
          (* too large integer *)
          Cil.mkString ~loc (Integer.to_string n),  Str_Z
        | Some ty, _ when Gmp_types.Q.is_t ty ->
          mk_real (Integer.to_string n),  Str_R
        | (None | Some _), _ ->
          (* do not keep the initial string representation because the generated
             constant must reflect its type computed by the type system. For
             instance, when translating [INT_MAX+1], we must generate a [long
             long] addition and so [1LL]. If we keep the initial string
             representation, the kind would be ignored in the generated code and
             so [1] would be generated. *)
          Cil.kinteger64 ~loc ~kind n, C_number
    in
    M.return (e, Some (strnum, ""))
  | BinOp {ity; binop = Lt | Gt | Le | Ge | Eq | Ne as binop; op1; op2} ->
    let binop = compile_binop binop in
    let* e1 = compile op1 in
    let* e2 = compile op2 in
    let name = Misc.name_of_binop binop in
    let* e = M.modifying_env @@ fun env ->
      Translate_utils.comparison_to_exp ~loc kf env ity binop e1 e2 ~name origin
    in
    M.return (e, Some (Analyses_types.C_number, name))
  | BinOp {ity; binop = Plus | Minus | Mult as binop; op1; op2} ->
    let binop = compile_binop binop in
    let* e1 = compile op1 in
    let* e2 = compile op2 in
    let* e = match ity with
      | Gmpz ->
        M.modifying_env @@ fun env ->
        Gmp.Z.binop ~loc origin binop env kf e1 e2
      | Rational ->
        M.modifying_env @@ fun env ->
        Gmp.Q.binop ~loc origin binop env kf e1 e2
      | Analyses_types.C_integer _
      | Analyses_types.C_float _
      | Analyses_types.Real
      | Analyses_types.Nan ->
        let ty = Typing.typ_of_number_ty ity in
        M.return @@ Cil.new_exp ~loc @@ BinOp (binop, e1, e2, ty)
    in
    M.return (e, Some (Analyses_types.C_number, Misc.name_of_binop binop))
  | BinOp ({binop = Div | Mod} as binop_node) ->
    compile_div_mod ~origin binop_node
  | Lval lval ->
    M.maybe_with_term_loc origin @@
    let* lval, name = M.without_registering_adata @@ compile_lval lval in
    let* {loc} = M.read in
    let e = Smart_exp.lval ~loc lval in
    let* () = M.Option.iter (assert_register_term ~loc e) origin in
    M.return (e, Some (Analyses_types.C_number, name))
  | SizeOf ty ->
    let e = Cil.sizeOf ~loc ty in
    let* () = M.Option.iter (assert_register_term ~loc ~force:true e) origin in
    M.return (e, Some (Analyses_types.C_number, "sizeof"))

and compile_div_mod ~origin {ity; binop; op1; op2} =
  assert (binop = Div || binop = Mod);
  let* {kf; loc} = M.read in
  let ty = Typing.typ_of_number_ty ity in
  let binop = compile_binop binop in
  let* e1 = compile op1 in
  let* e =
    match ity with
    | Gmpz ->
      let* {adata} = M.get in
      let* adata2 = M.modifying_env (Assert.empty ~loc kf) in
      let* () = M.modify (fun state -> {state with adata = adata2}) in
      let* e2 = compile op2 in
      let* {adata = adata2} = M.get in
      let* adata = M.modifying_env (fun env -> Assert.merge_right ~loc env adata2 adata) in
      let* () = M.modify (fun state -> {state with adata}) in
      (* TODO: preventing division by zero should not be required anymore.
         RTE should do this automatically. *)
      let* logic_env = M.get_logic_env in
      let origin, t2 = match origin with
        | Some ({term_node = TBinOp ((Div | Mod), _, t2)} as o) -> o, t2
        | _ -> Options.fatal "expected division or modulo operator as origin"
      in
      let ctx = Typing.get_number_ty ~logic_env origin in
      (* [TODO] can now do better since the type system got some info about
         possible values of [t2] *)
      (* guarding divisions and modulos *)
      let zero = Logic_const.tinteger 0 in
      Typing.preprocess_term ~use_gmp_opt:true ~ctx ~logic_env zero;
      let* guard =
        let* zero = compile {enode = Integer Z.zero; origin = Some zero} in
        let name = Misc.name_of_binop binop ^ "_guard" in
        M.modifying_env (fun env ->
            Translate_utils.comparison_to_exp
              ~loc
              kf
              env
              Typing.gmpz
              ~name
              Ne
              e2
              zero
              (Some origin)
          )
      in
      let p = Logic_const.prel ~loc (Rneq, t2, zero) in
      let* cond =
        M.modifying_env @@ fun env ->
        Assert.runtime_check
          ~adata:adata2
          ~pred_kind:Assert
          (Env.annotation_kind env)
          kf
          env
          guard
          p
      in
      Env.add_assert kf cond p;
      let mk_stmts _v e =
        assert (Gmp_types.Z.is_t ty);
        let name = Gmp.Z.name_arith_bop binop in
        let instr = Smart_stmt.rtl_call ~loc ~prefix:"" name [ e; e1; e2 ] in
        [ cond; instr ]
      in
      let name = Misc.name_of_binop binop in
      M.modifying_env (fun env -> Gmp.Z.new_var ~loc ~name env kf None mk_stmts)
    | Rational ->
      let* e2 = compile op2 in
      M.modifying_env (fun env -> Gmp.Q.binop ~loc origin binop env kf e1 e2)
    | Analyses_types.C_integer _
    | Analyses_types.C_float _
    | Analyses_types.Real
    | Analyses_types.Nan ->
      let* e2 = compile op2 in
      M.return @@ Cil.new_exp ~loc @@ BinOp (binop, e1, e2, ty)
  in
  M.return (e, Some (Analyses_types.C_number, ""))

and compile_varinfo = function
  | Varinfo.Logic_varinfo varinfo -> M.return varinfo
  | Varinfo.(Fresh_varinfo {name; ty; origin}) ->
    M.with_loc origin.term_loc @@
    let* {loc; kf} = M.read in
    M.modifying_env (fun env ->
        let vi, _, env =
          Env.new_var ~loc ~name env kf (Some origin) ty (fun _ _ -> [])
        in
        vi, env)

and compile_lhost = function
  | Var vi ->
    let* v = compile_varinfo vi in
    M.return (Cil_types.Var v, v.vorig_name)
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


let generate_and_compile ~loc ~adata ~env ~kf m source =
  let interlang, (), _ =
    let env = Interlang_gen.{kf; loc; env; rte = true;
                             vars = Cil_datatype.Term.Map.empty} in
    let state = Cil_datatype.Term.Map.empty (* local variables *) in
    Interlang_gen.M.run ~env ~state @@ m source
  in
  let cil, (), {env; adata} =
    M.run ~env:{Conf.kf; loc; adata_register = true} ~state:{Conf.env; adata} @@
    compile interlang
  in
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
  loc:Cil_types.location ->
  adata:Assert.t ->
  env:Env.t ->
  kf:Cil_types.kernel_function ->
  'a ->
  Cil_types.exp * Assert.t * Env.t

let try_il_compiler il old ~loc ~adata ~env ~kf x =
  try_interlang
    (fun () -> generate_and_compile ~loc ~adata ~env ~kf il x)
    (fun () -> old ~loc ~adata ~env ~kf x)
