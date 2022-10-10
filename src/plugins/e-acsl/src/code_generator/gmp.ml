(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2022                                               *)
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
open Analyses_types
module Error = Translation_error

(**************************************************************************)
(************************* Calls to builtins ******************************)
(**************************************************************************)

let apply_on_var ~loc funname e =
  let prefix =
    let ty = Cil.typeOf e in
    if Gmp_types.Z.is_t ty then "__gmpz_"
    else if Gmp_types.Q.is_t ty then "__gmpq_"
    else assert false
  in
  Smart_stmt.rtl_call ~loc ~prefix funname [ e ]

let init ~loc e = apply_on_var "init" ~loc e
let clear loc e = apply_on_var "clear" ~loc e

exception Longlong of ikind

let get_set_suffix_and_arg res_ty e =
  let ty = Cil.typeOf e in
  let exp_number_ty = Typing.number_ty_of_typ ~post:true ty in
  let res_number_ty = Typing.number_ty_of_typ ~post:true res_ty in
  let args_uisi e =
    if Gmp_types.Z.is_t res_ty then [ e ]
    else begin
      assert (Gmp_types.Q.is_t res_ty);
      [ e; Cil.one ~loc:e.eloc ]
    end
  in
  match (exp_number_ty, res_number_ty) with
  | Gmpz, Gmpz | Rational, Rational -> "", [ e ]
  | Gmpz, Rational -> "_z", [ e ]
  | Rational, Gmpz -> "_q", [ e ]
  | C_integer IChar, _ ->
    (if Cil.theMachine.Cil.theMachine.char_is_unsigned then "_ui"
     else "_si"),
    args_uisi e
  | C_integer (IBool | IUChar | IUInt | IUShort | IULong), _ ->
    "_ui", args_uisi e
  | C_integer (ISChar | IShort | IInt | ILong), _ -> "_si", args_uisi e
  | C_integer (ILongLong | IULongLong as ikind), _ -> raise (Longlong ikind)
  | C_float (FDouble | FFloat), _ -> "_d", [ e ]
  (* FFloat is a strict subset of FDouble (modulo exceptional numbers)
     Hence, calling [set_d] for both of them is sound.
     HOWEVER: the machdep MUST NOT be vulnerable to double rounding
     [TODO] check the statement above *)
  | C_float FLongDouble, _ -> Error.not_yet "creating gmp from long double"
  | Gmpz, _ | Rational, _ | Real, _ | Nan, _ -> (
      match Cil.unrollType ty with
      | TPtr(TInt(IChar, _), _) ->
        "_str",
        (* decimal base for the number given as string *)
        [ e; Cil.integer ~loc:e.eloc 10 ]
      | _ ->
        assert false
    )

let generic_affect ~loc fname lv ev e =
  let ty = Cil.typeOf ev in
  if Gmp_types.Z.is_t ty || Gmp_types.Q.is_t ty then begin
    let suf, args = get_set_suffix_and_arg ty e in
    Smart_stmt.rtl_call ~loc ~prefix:"" (fname ^ suf) (ev :: args)
  end else
    Smart_stmt.assigns ~loc:e.eloc ~result:lv e

let affect ~loc lv ev e =
  let fname =
    let ty = Cil.typeOf ev in
    if Gmp_types.Z.is_t ty then "__gmpz_set"
    else if Gmp_types.Q.is_t ty then "__gmpq_set"
    else ""
  in
  try generic_affect ~loc fname lv ev e
  with Longlong _ ->
    Error.not_yet "quantification over long long and requiring GMP"

let init_set ~loc lv ev e =
  let mpz_init_set fname =
    try generic_affect ~loc fname lv ev e
    with
    | Longlong IULongLong ->
      (match e.enode with
       | Lval elv ->
         assert (Gmp_types.Z.is_t (Cil.typeOf ev));
         let call =
           Smart_stmt.rtl_call ~loc
             ~prefix:""
             "__gmpz_import"
             [ ev;
               Cil.one ~loc;
               Cil.one ~loc;
               Cil.sizeOf ~loc (TInt(IULongLong, []));
               Cil.zero ~loc;
               Cil.zero ~loc;
               Cil.mkAddrOf ~loc elv ]
         in
         Smart_stmt.block_stmt (Cil.mkBlock [ init ~loc ev; call ])
       | _ ->
         Error.not_yet "unsigned long long expression requiring GMP")
    | Longlong ILongLong ->
      Error.not_yet "long long requiring GMP"
  in
  let ty = Cil.typeOf ev in
  if Gmp_types.Z.is_t ty then
    mpz_init_set "__gmpz_init_set"
  else if Gmp_types.Q.is_t ty then
    Smart_stmt.block_stmt
      (Cil.mkBlock
         [ init ~loc ev ;
           affect ~loc lv ev e ])
  else
    mpz_init_set ""

module Z = struct

  let name_arith_bop = function
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
    | Lt | Gt | Le | Ge | Eq | Ne | LAnd | LOr | PlusPI | MinusPI
    | MinusPP as bop ->
      Options.fatal
        "Operation '%a' either not arithmetic or not supported on GMP integers"
        Printer.pp_binop bop

  let new_var_and_mpz_init ~loc ?scope ?name env kf t mk_stmts =
    Env.new_var
      ~loc
      ?scope
      ?name
      env
      kf
      t
      (Gmp_types.Z.t ())
      (fun v e -> init ~loc e :: mk_stmts v e)

end

module Q = struct
  let name_arith_bop = function
    | PlusA -> "__gmpq_add"
    | MinusA -> "__gmpq_sub"
    | Mult -> "__gmpq_mul"
    | Div -> "__gmpq_div"
    | Mod | Lt | Gt | Le | Ge | Eq | Ne | BAnd | BXor | BOr | LAnd | LOr
    | Shiftlt | Shiftrt | PlusPI | MinusPI | MinusPP -> assert false

  exception Not_a_decimal of string
  exception Is_a_float

  (* The possible float suffixes (ISO C 6.4.4.2) are lLfF.
     dD is a GNU extension accepted by Frama-C (only!) in the logic *)
  let float_suffixes = [ 'f'; 'F'; 'l'; 'L'; 'd'; 'D' ]

  (* Computes the fractional representation of a decimal number.
     Does NOT perform reduction.
     Example: [dec_to_frac "43.567"] evaluates to ["43567/1000"]
     Complexity: Linear
     Original Author: Frédéric Recoules

     It iterates **once** over [str] during which three cases are distinguished,
     example for "43.567":
     Case1: pre: no '.' has been found yet ==> copy current char into buf
      buf: | 4 |   |   |   |   |   |   |   |   |   |   |   |
           | 4 | 3 |   |   |   |   |   |   |   |   |   |   |
     Case2: mid: current char is '.' ==> put "/1" into buf at [(length str) - 1]
      buf: | 4 | 3 |   |   |   | / | 1 |   |   |   |   |   |
     Case3: post: a '.' was found ==> put current char in numerator AND '0' in den
      buf: | 4 | 3 | 5 |   |   | / | 1 | 0 |   |   |   |   |
           | 4 | 3 | 5 | 6 |   | / | 1 | 0 | 0 |   |   |   |
           | 4 | 3 | 5 | 6 | 7 | / | 1 | 0 | 0 | 0 |   |   | *)
  let decimal_to_fractional str =
    let rec post str len buf len' i =
      if i = len then
        Bytes.sub_string buf 0 len'
      else
        match String.unsafe_get str i with
        | c when '0' <= c && c <= '9' ->
          Bytes.unsafe_set buf (i - 1) c;
          Bytes.unsafe_set buf len' '0';
          post str len buf (len' + 1) (i + 1)
        | c when List.mem c float_suffixes ->
          (* [JS] a suffix denoting a C type is possible *)
          assert (i = len - 1);
          raise Is_a_float
        | _ ->
          raise (Not_a_decimal str)
    in
    let mid buf len =
      Bytes.unsafe_set buf (len - 1) '/';
      Bytes.unsafe_set buf len '1'
    in
    let rec pre str len buf i =
      if i = len then
        str
      else
        match String.unsafe_get str i with
        | '.' ->
          mid buf len;
          post str len buf (len + 1) (i + 1)
        | c when '0' <= c && c <= '9' ->
          Bytes.unsafe_set buf i c;
          pre str len buf (i + 1)
        | c when List.mem c float_suffixes ->
          (* [JS] a suffix denoting a C type is possible *)
          assert (i = len - 1);
          raise Is_a_float
        | _ ->
          raise (Not_a_decimal str)
    in
    let strlen = String.length str in
    let buflen =
      (* The fractional representation is at most twice as lengthy
         as the decimal one. *)
      2 * strlen
    in
    try pre str strlen (Bytes.create buflen) 0
    with Is_a_float -> str (* just left it unchanged *)

  (* ACSL considers strings written in decimal expansion to be reals.
     Yet GMPQ considers them to be double:
     they MUST be converted into fractional representation. *)
  let normalize_str str =
    try
      decimal_to_fractional str
    with Invalid_argument _ ->
      Error.not_yet "number not written in decimal expansion"
end

let normalize_str = Q.normalize_str

let () =
  Env.gmp_clear_ref := clear

(*
Local Variables:
compile-command: "make -C ../../../../.."
End:
*)
