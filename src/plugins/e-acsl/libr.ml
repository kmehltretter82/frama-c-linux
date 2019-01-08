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

let t () =
  (* When support for irrationals will be provided,
    the following typ MUST be changed into a typ that can represent them.
    It is sound to use GMPQ for the time being since irrationals
    raise not_yet. *)
  Gmp.q_t ()

let is_t ty = Cil_datatype.Typ.equal ty (t ())

(* No init_set for GMPQ: init then set separately *)
let init_set ~loc lval vi_e e =
  Cil.mkStmt
    ~valid_sid:true
    (Block (Cil.mkBlock
      [ Gmp.init ~loc vi_e ;
        Gmp.affect ~loc lval vi_e e ]))

let mk_real ~loc ?name e env t_opt =
  if Gmp.is_z_t (Cil.typeOf e) then
    (* GMPQ has no builtin for creating Q from Z. Hence:
      1) Get the MPZ as a string: gmZ_get_str
      2) Set the MPQ with that string: gmpQ_set_str *)
    Error.not_yet "reals: creating Q from Z"
  else
    let _, e, env = Env.new_var
      ~loc
      ?name
      env
      t_opt
      (t ())
      (fun vi vi_e ->
        [ Gmp.init ~loc vi_e ;
          Gmp.affect ~loc (Cil.var vi) vi_e e ])
    in
    e, env

(* ACSL considers strings written in decimal expansion to be reals.
  Yet GMPQ considers them to be double:
  they MUST be converted into fractional representation. *)
let normalize_str str =
  try
    Misc.dec_to_frac str
  with Invalid_argument _ ->
    Error.not_yet "number not written in decimal expansion"

let cast_to_z ~loc ?name e env =
  ignore (loc, name, e, env);
  Error.not_yet "reals: cast from R to Z"

let add_cast ~loc ?name e env ty =
  (* TODO: The best solution would actually be to directly write all the
           needed functions as C builtins then just call them here
           depending on the situation at hand. *)
  assert (is_t (Cil.typeOf e));
  let get_double e env =
    let _, e, env = Env.new_var
      ~loc
      ?name
      env
      None
      Cil.doubleType
      (fun v _ ->
        [ Misc.mk_call ~loc ~result:(Cil.var v) "__gmpq_get_d" [ e ] ])
    in
    e, env
  in
  match ty with
  | TFloat(FLongDouble, _) ->
    (* The biggest floating-point type we can extract from GMPQ is double *)
    Error.not_yet "R to long double"
  | TFloat(FDouble, _) ->
    get_double e env
  | TFloat(FFloat, _) ->
    (* There is no such thing as [get_float] in GMPQ.
      Fortunately, [float] \subset [double].
      HOWEVER: going through double as intermediate step might be unsound
               since it could cause double rounding.
               See: [Boldo2013, Sec 2.2]
                    https://hal.inria.fr/hal-00777639/document *)
    let e, env = get_double e env in
    Options.warning
      ~once:true "R to float: double rounding might cause unsoundness";
    Cil.mkCastT ~force:false ~e ~oldt:Cil.doubleType ~newt:ty, env
  | TInt(IULongLong, _) ->
    (* The biggest C integer type we can extract from GMP is ulong *)
    Error.not_yet "R to unsigned long long"
  | TInt _ ->
    (* 1) Cast R to Z using cast_to_z
       2) Extract ulong from Z
       3) Potentially cast ulong to ty *)
    Error.not_yet "R to TInt"
  | _ ->
    Error.not_yet "R to <typ>"

let potentially_mk_real ~loc e env =
  (* TODO: sounds mergeable with add_cast *)
  if is_t (Cil.typeOf e) then e, env else mk_real ~loc e env None

let cmp ~loc bop e1 e2 env t_opt =
  let fname = "__gmpq_cmp" in
  let name = Misc.name_of_binop bop in
  let e1, env = potentially_mk_real ~loc e1 env in
  let e2, env = potentially_mk_real ~loc e2 env in
  let _, e, env = Env.new_var
    ~loc
    env
    t_opt
    ~name
    Cil.intType
    (fun v _ -> [ Misc.mk_call ~loc ~result:(Cil.var v) fname [ e1; e2 ] ])
  in
  Cil.new_exp ~loc (BinOp(bop, e, Cil.zero ~loc, Cil.intType)), env

let name_arith_bop = function
  | PlusA -> "__gmpq_add"
  | MinusA -> "__gmpq_sub"
  | Mult -> "__gmpq_mul"
  | Div -> "__gmpq_div"
  | Mod | Lt | Gt | Le | Ge | Eq | Ne | BAnd | BXor | BOr | LAnd | LOr
  | Shiftlt | Shiftrt | PlusPI | IndexPI | MinusPI | MinusPP -> assert false

let new_var_and_init ~loc ?scope ?name env t_opt mk_stmts =
  Env.new_var
    ~loc
    ?scope
    ?name
    env
    t_opt
    (t ())
    (fun v e -> Gmp.init ~loc e :: mk_stmts v e)

let mk_binop ~loc bop e1 e2 env t_opt =
  let name = name_arith_bop bop in
  let e1, env = potentially_mk_real ~loc e1 env in
  let e2, env = potentially_mk_real ~loc e2 env in
  let mk_stmts _ e = [ Misc.mk_call ~loc name [ e; e1; e2 ] ] in
  let name = Misc.name_of_binop bop in
  let _, e, env = new_var_and_init ~loc ~name env t_opt mk_stmts in
  e, env