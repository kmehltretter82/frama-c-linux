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

(* Implements Figure 3 of J. Signoles' JFLA'15 paper "Rester statique pour
   devenir plus rapide, plus précis et plus mince".
   Also implements a support for real numbers. *)
let dkey = Options.Dkey.interval
module Error = Error.Make(struct let phase = dkey end)

(* ********************************************************************* *)
(* Basic datatypes and operations *)
(* ********************************************************************* *)

type ival =
  | Ival of Ival.t
  | Float of fkind * float option (* a float constant, if any *)
  | Rational
  | Real
  | Nan

module D =
  Datatype.Make_with_collections
    (struct
      type t = ival
      let name = "E_ACSL.Interval.t"
      let reprs = [ Float (FFloat, Some 0.); Rational; Real; Nan ]
      include Datatype.Undefined

      let compare i1 i2 =
        if i1 == i2 then 0
        else
          match i1, i2 with
          | Ival i1, Ival i2 ->
            Ival.compare i1 i2
          | Float (k1, f1), Float (k2, f2) ->
            (* faster to compare a kind than a float *)
            let n = Stdlib.compare k1 k2 in
            if n = 0 then Stdlib.compare f1 f2 else n
          | Ival _, (Float _ | Rational | Real | Nan)
          | Float _, (Rational | Real | Nan)
          | Rational, (Real | Nan)
          | Real, Nan ->
            -1
          | Nan, (Ival _ | Float _ | Rational | Real)
          | Real, (Ival _ | Float _ | Rational)
          | Rational, (Ival _ | Float _)
          | Float _, Ival _ ->
            1
          | Rational, Rational | Real, Real | Nan, Nan ->
            assert false

      let equal = Datatype.from_compare

      let hash = function
        | Ival i -> 7 * Ival.hash i
        | Float(k, f) -> 17 * Hashtbl.hash f + 97 * Hashtbl.hash k
        | Rational -> 787
        | Real -> 1011
        | Nan -> 1277

      let pretty fmt = function
        | Ival i -> Ival.pretty fmt i
        | Float(_, Some f) -> Format.pp_print_float fmt f
        | Float(FFloat, None) -> Format.pp_print_string fmt "float"
        | Float(FDouble, None) -> Format.pp_print_string fmt "double"
        | Float(FLongDouble, None) -> Format.pp_print_string fmt "long double"
        | Rational -> Format.pp_print_string fmt "Rational"
        | Real -> Format.pp_print_string fmt "Real"
        | Nan -> Format.pp_print_string fmt "NaN"

    end)

let is_included i1 i2 = match i1, i2 with
  | Ival i1, Ival i2 -> Ival.is_included i1 i2
  | Float(k1, f1), Float(k2, f2) ->
    Stdlib.compare k1 k2 <= 0
    && (match f1, f2 with
        | None, None | Some _, None -> true
        | None, Some _ -> false
        | Some f1, Some f2 -> f1 = f2)
  | (Ival _ | Float _ | Rational), (Rational | Real)
  | Real, Real
  | Nan, Nan ->
    true
  (* floats and integer are not comparable: *)
  | Ival _, Float _ | Float _, Ival _
  (* nan is comparable to noone, but itself: *)
  | (Ival _ | Float _ | Rational | Real), Nan
  | Nan, (Ival _ | Float _ | Rational | Real)
  (* cases for reals and rationals: *)
  | Real, (Ival _ | Float _ | Rational)
  | Rational, (Ival _ | Float _) ->
    false

let widen = function
  | Ival iv ->
    let min, max = Ival.min_and_max iv in
    Ival (Ival.inject_range min max)
  | Float _ | Rational | Real | Nan as i -> i

let lift_unop f = function
  | Ival iv -> Ival (f iv)
  | Float _ ->
    (* any unary operator over a float generates a rational
       TODO: actually, certainly possible to generate a float *)
    Rational
  | Rational | Real | Nan as i ->
    i

let lift_arith_binop f i1 i2 = match i1, i2 with
  | Ival i1, Ival i2 ->
    Ival (f i1 i2)
  | (Ival _ | Float _), Float _
  | Float _, Ival _
  | (Ival _ | Float _ | Rational), Rational
  | Rational, (Ival _ | Float _) ->
    Rational
  | (Ival _ | Float _ | Rational | Real), Real
  | Real, (Ival _ | Float _ | Rational) ->
    Real
  | (Ival _ | Float _ | Rational | Real | Nan), Nan
  | Nan, (Ival _ | Float _ | Rational | Real) ->
    Nan

let join i1 i2 = match i1, i2 with
  | Ival iv, i when Ival.is_bottom iv -> i
  | i, Ival iv when Ival.is_bottom iv -> i
  | Ival i1, Ival i2 ->
    Ival (Ival.join i1 i2)
  | Float(k1, _), Float(k2, _) ->
    let k = if Cil.frank k1 >= Cil.frank k2 then k1 else k2 in
    Float(k, None (* lost value, if any before *))
  | Ival iv, Float(k, _)
  | Float(k, _), Ival iv ->
    begin
      match Ival.min_and_max iv with
      | None, None ->
        (* unbounded integers *)
        Rational
      | Some min, Some max ->
        (* if the interval of integers fits into the float types, then return
           this float type; otherwise return Rational *)
        (try
           let to_float n = Int64.to_float (Integer.to_int64_exn n) in
           let mini, maxi = to_float min, to_float max in
           let minf, maxf = match k with
             | FFloat ->
               Floating_point.most_negative_single_precision_float,
               Floating_point.max_single_precision_float
             | FDouble ->
               -. Float.max_float,
               Float.max_float
             | FLongDouble ->
               raise Exit
           in
           if mini >= minf && maxi <= maxf then Float(k, None) else Rational
         with Z.Overflow | Exit ->
           Rational)
      | None, Some _ | Some _, None ->
        assert false
    end
  | (Ival _ | Float _ | Rational), (Float _ | Rational)
  | Rational, Ival _ ->
    Rational
  | (Ival _ | Float _ | Rational | Real), Real
  | Real, (Ival _ | Float _ | Rational) ->
    Real
  | (Ival _ | Float _ | Rational | Real | Nan), Nan
  | Nan, (Ival _ | Float _ | Rational | Real) ->
    Nan

let meet i1 i2 = match i1, i2 with
  | Ival iv, _ when Ival.is_bottom iv -> Ival iv
  | _, Ival iv when Ival.is_bottom iv -> Ival iv
  | Ival i1, Ival i2 ->
    Ival (Ival.meet i1 i2)
  | Float(k1, Some f1), Float(k2, Some f2) ->
    if Float.equal f1 f2 then
      let k = if Cil.frank k1 >= Cil.frank k2 then k2 else k1 in
      Float (k, Some f1)
    else Ival Ival.bottom
  | Float(k, Some f), Float(k', None)
  | Float(k',None), Float(k, Some f) ->
    let f_in_k' = match k' with
      | FFloat ->
        let minf,maxf =
          Floating_point.most_negative_single_precision_float,
          Floating_point.max_single_precision_float
        in minf <= f && f <= maxf
      | FDouble
      | FLongDouble ->
        true
    in if f_in_k' then Float(k, Some f) else Ival Ival.bottom
  | Float(k1, None), Float(k2, None) ->
    let k = if Cil.frank k1 >= Cil.frank k2 then k2 else k1 in
    Float(k, None)
  | Float(k, Some f), Ival iv
  | Ival iv, Float(k, Some f) ->
    begin
      match Ival.min_and_max iv with
      | None, None ->
        (* unbounded integers *)
        Float(k, Some f)
      | Some min, Some max ->
        (* if the float type fits into the interval of integers, then return
           this float type; otherwise return Rational *)
        (try
           let to_float n = Int64.to_float (Integer.to_int64_exn n) in
           let mini, maxi = to_float min, to_float max in
           if mini <= f && maxi >= f then Float(k, Some f) else Ival Ival.bottom
         with Z.Overflow | Exit ->
           Rational)
      | None, Some _ | Some _, None ->
        assert false
    end
  | Ival iv, Float(k, None)
  | Float(k, None), Ival iv ->
    begin
      match Ival.min_and_max iv with
      | None, None ->
        (* unbounded integers *)
        Float(k, None)
      | Some min, Some max ->
        (* if the float type fits into the interval of integers, then return
           this float type; otherwise return Rational *)
        (try
           let to_float n = Int64.to_float (Integer.to_int64_exn n) in
           let mini, maxi = to_float min, to_float max in
           let minf, maxf = match k with
             | FFloat ->
               Floating_point.most_negative_single_precision_float,
               Floating_point.max_single_precision_float
             | FDouble ->
               -. Float.max_float,
               Float.max_float
             | FLongDouble ->
               raise Exit
           in
           if mini <= minf && maxi >= maxf then Float(k, None) else Rational
         with Z.Overflow | Exit ->
           Rational)
      | None, Some _ | Some _, None ->
        assert false
    end
  | (Ival _ | Float _ | Rational), (Float _ | Rational)
  | Rational, Ival _ ->
    Rational
  | (Ival _ | Float _ | Rational | Real), Real
  | Real, (Ival _ | Float _ | Rational) ->
    Real
  | (Ival _ | Float _ | Rational | Real | Nan), Nan
  | Nan, (Ival _ | Float _ | Rational | Real) ->
    Nan

let is_singleton_int = function
  | Ival iv -> Ival.is_singleton_int iv
  | Float _ | Rational | Real | Nan -> false

(* TODO: soundness of any downcast is not checked *)
let cast ~src ~dst = match src, dst with
  | Ival i1, Ival i2 ->
    Ival (Ival.meet i1 i2)
  | _, Float(_, Some _) ->
    assert false
  | Rational, Real
  | Float _, (Rational | Real) ->
    src
  | _, _ ->
    (* No need to optimize the other cases: if someone writes a cast
       (in particular, from integer to float/real or conversely), it is
       certainly on purpose . *)
    dst

(* a-b; or 0 if negative *)
let length a b = Z.max Z.zero (Z.add Z.one (Z.sub a b))

(* minimal distance between two intervals given by their respective lower and
   upper bounds, i.e. the length between the lower bound of the second interval
   bound and the upper bound of the first interval. *)
let min_delta (_, max1) (min2, _) = match max1, min2 with
  | Some m1, Some m2 -> length m2 m1
  | _, None | None, _ -> Z.zero

(* maximal distance between between two intervals given by their respective
   lower and upper bounds, i.e. the length between the upper bound of the second
   interval and the lower bound of the first interval.
   @return None for \infty *)
let max_delta (min1, _) (_, max2) = match min1, max2 with
  | Some m1, Some m2 -> Some (length m2 m1)
  | _, None | None, _ -> None

(* ********************************************************************* *)
(* constructors and destructors *)
(* ********************************************************************* *)

let extract_ival = function
  | Ival iv -> iv
  | Float _ | Rational | Real | Nan -> assert false

let bottom = Ival Ival.bottom
let top_ival = Ival (Ival.inject_range None None)
let singleton n = Ival (Ival.inject_singleton n)
let singleton_of_int n = singleton (Integer.of_int n)
let ival min max = Ival (Ival.inject_range (Some min) (Some max))

let interv_of_unknown_block =
  (* since we have no idea of the size of this block, we take the largest
     possible one which is unfortunately quite large *)
  lazy (ival Integer.zero (Bit_utils.max_byte_address ()))

(* ********************************************************************* *)
(* main algorithm *)
(* ********************************************************************* *)

(* The boolean indicates whether we have real numbers *)
let rec interv_of_typ ty = match Cil.unrollType ty with
  | TInt (k,_) as ty ->
    let n = Cil.bitsSizeOf ty in
    let l, u =
      if Cil.isSigned k then Cil.min_signed_number n, Cil.max_signed_number n
      else Integer.zero, Cil.max_unsigned_number n
    in
    ival l u
  | TEnum(enuminfo, _) ->
    interv_of_typ (TInt(enuminfo.ekind, []))
  | _ when Gmp_types.Z.is_t ty ->
    top_ival
  | TFloat (k, _) ->
    Float(k, None)
  | _ when Gmp_types.Q.is_t ty ->
    Rational (* only rationals are implemented *)
  | TVoid _ | TPtr _ | TArray _ | TFun _ | TComp _ | TBuiltin_va_list _ ->
    Nan
  | TNamed _ ->
    assert false

let extended_interv_of_typ ty = match interv_of_typ ty with
  | Ival iv ->
    let l,u = Ival.min_int iv, Ival.max_int iv in
    let u = match u with
      | Some u -> Some (Integer.add u Integer.one)
      | None -> None
    in
    Ival (Ival.inject_range l u);
  | Rational | Real | Nan | Float (_,_) as i
    -> i

let interv_of_logic_typ = function
  | Ctype ty -> interv_of_typ ty
  | Linteger -> top_ival
  | Lreal -> Real
  | Ltype _ -> Error.not_yet "user-defined logic type"
  | Lvar _ -> Error.not_yet "type variable"
  | Larrow _ -> Nan

let ikind_of_ival iv =
  if Ival.is_bottom iv then IInt
  else match Ival.min_and_max iv with
    | Some l, Some u ->
      let is_pos = Integer.ge l Integer.zero in
      let lkind = Cil.intKindForValue l is_pos in
      let ukind = Cil.intKindForValue u is_pos in
      (* kind corresponding to the interval *)
      let kind = if Cil.intTypeIncluded lkind ukind then ukind else lkind in
      (* convert the kind to [IInt] whenever smaller. *)
      if Cil.intTypeIncluded kind IInt then IInt else kind
    | None, None -> raise Cil.Not_representable (* GMP *)
    (* TODO: do not raise an exception, but returns a value instead *)
    | None, Some _ | Some _, None ->
      (* Semi-open interval that can happen when computing the interval of shift
         operations if the computation overflows *)
      (* TODO: do not raise an exception, but returns a value instead *)
      raise Cil.Not_representable (* GMP *)

(* function call profiles (intervals for their formal parameters) *)
module Profile = struct
  include Datatype.List_with_collections
      (D)
      (struct
        let module_name = "E_ACSL.Interval.Logic_function_env.Profile"
      end)
end

module Id_term_in_profile =
  Datatype.Pair_with_collections
    (Misc.Id_term)
    (Profile)
    (struct let module_name = "E_ACSL.Typing.Id_term_in_profile" end)

module Logic_environment : sig
  type t
  val add_let_quantif_binding : t -> logic_var -> ival -> t
  val create : logic_var list -> ival list -> t
  val find : t -> logic_var -> ival
  val get_profile : t -> ival list
end
= struct
  type env = (logic_var * ival) list

  type t = { profile : logic_var list * Profile.t;
             let_quantif_bind : env}

  let add_let_quantif_binding env x i =
    { env with let_quantif_bind = (x, i) :: env.let_quantif_bind }

  let create args params_ival =
    { profile = args , params_ival;
      let_quantif_bind = [] }

  let find env x =
    try List.assoc x env.let_quantif_bind
    with Not_found ->
      let rec find = function
        |(y::_), (i ::_) when Cil_datatype.Logic_var.equal x y -> i
        | (_ :: l) , (_ :: l') -> find (l, l')
        | [] , _ :: _
        | _ :: _, [] -> Options.abort "inconsistent function profile"
        |[], [] -> raise Not_found
      in find env.profile

  let get_profile env = snd env.profile

end

(* Memoization module which retrieves the computed info of some terms. If the
   info is already computed for a term, it is never recomputed *)
module Memo: sig
  val memo:
    profile:Profile.t -> (term -> ival) -> term -> ival Error.or_error
  val get: profile:Profile.t -> term -> ival Error.or_error
  val clear: unit -> unit
end = struct
  (* The comparison over terms is the physical equality. It cannot be the
     structural one (given by [Cil_datatype.Term.equal]) for efficiency.

     By construction (see prepare_ast.ml), there are no physically equal terms
     in the E-ACSL's generated AST, but
     - type info of many terms are accessed several times
     - the translation of E-ACSL guarded quantifications generates
       new terms (see module {!Quantif}) which must be typed. The term
       corresponding to the bound variable [x] is actually used twice: once in
       the guard and once for encoding [x+1] when incrementing it. *)
  let tbl : ival Error.result Misc.Id_term.Hashtbl.t =
    Misc.Id_term.Hashtbl.create 97

  (* The interval of the logic function
     \\@ logic integer f (integer x) = x + 1;
     depends on the interval of [x]. The same term [x+1] can be infered to be
     in different intervals if the function [f] is applied several times with
     different arguments. In this case, we add the interval of [x] as a key
     to retrieve the type of [x+1].
     There are two other kinds of binders for logical variables: [TLet] and
     the quantifiers, however in those cases, a term is only ever translated
     once. Since we test with physical equality, the information is not needed
     to determine the environment.*)

  let dep_tbl : ival Error.result Id_term_in_profile.Hashtbl.t
    = Id_term_in_profile.Hashtbl.create 97

  let get_dep profile t =
    try Id_term_in_profile.Hashtbl.find dep_tbl (t,profile)
    with Not_found -> Error.not_memoized ()

  let get_nondep t =
    try Misc.Id_term.Hashtbl.find tbl t
    with Not_found -> Error.not_memoized ()

  let get ~profile t =
    match profile with
    | [] -> get_nondep t
    | _::_ -> get_dep profile t

  let memo_nondep f t =
    try Misc.Id_term.Hashtbl.find tbl t
    with Not_found ->
      let x =
        try Error.Res (f t)
        with Error.Not_yet _ | Error.Typing_error _ as exn -> Error.Err exn
      in
      Misc.Id_term.Hashtbl.add tbl t x;
      x

  let memo_dep f t profile =
    try
      Id_term_in_profile.Hashtbl.find dep_tbl (t, profile)
    with Not_found ->
      let x =
        try Error.Res (f t)
        with Error.Not_yet _ | Error.Typing_error _ as exn -> Error.Err exn
      in
      Id_term_in_profile.Hashtbl.add dep_tbl (t, profile) x;
      x

  let memo ~profile f t =
    match profile with
    | [] -> memo_nondep f t
    | _::_ -> memo_dep f t profile

  let clear () =
    Options.feedback ~level:4 "clearing the typing tables";
    Misc.Id_term.Hashtbl.clear tbl;
    Id_term_in_profile.Hashtbl.clear dep_tbl

end

(* ********************************************************************* *)
(* Main functions *)
(* ********************************************************************* *)

let infer_sizeof ty =
  try singleton_of_int (Cil.bytesSizeOf ty)
  with Cil.SizeOfError _ -> interv_of_typ Cil.theMachine.Cil.typeOfSizeOf

let infer_alignof ty =
  try singleton_of_int (Cil.bytesAlignOf ty)
  with Cil.SizeOfError _ -> interv_of_typ Cil.theMachine.Cil.typeOfSizeOf

(* Infer the interval of an extended quantifier \sum or \product.
   [lambda] is the interval of the lambda term, [min] (resp. [max]) is the
   interval of the minimum (resp. maximum) and [oper] is the identifier of the
   extended quantifier (\sum, or \product). The returned ival is the interval of
   the extended quantifier. *)
let infer_sum_product oper lambda min max = match lambda, min, max with
  | Ival lbd_iv, Ival lb_iv, Ival ub_iv ->
    (try
       let min_lambda, max_lambda = Ival.min_and_max lbd_iv in
       let minmax_lb = Ival.min_and_max lb_iv in
       let minmax_ub = Ival.min_and_max ub_iv in
       let lb, ub = match oper.lv_name with
         | "\\sum" ->
           (* the lower (resp. upper) bound is the min (resp. max) value of the
              lambda term, times the min (resp. max) distance between them if
              the sign is positive, or conversely if the sign is negative *)
           let lb = match min_lambda with
             | None -> None
             | Some z ->
               if Z.sign z = -1
               then Option.map (Z.mul z) (max_delta minmax_lb minmax_ub)
               else Some (Z.mul z (min_delta minmax_lb minmax_ub))
           in
           let ub = match max_lambda with
             | None -> None
             | Some z ->
               if Z.sign z = -1
               then Some (Z.mul z (min_delta minmax_lb minmax_ub))
               else Option.map (Z.mul z) (max_delta minmax_lb minmax_ub)
           in
           lb, ub
         | "\\product" ->
           (* the lower (resp. upper) bound is the min (resp. max) value of the
              lambda term in absolute value, power the min (resp. max) distance
              between them if the sign is positive, or conversely for both the
              lambda term and the exponent if the sign is negative. If the sign
              is negative, the minimum is also negative. *)
           let min, max =
             match min_lambda, max_lambda with
             | None, None as res -> res
             | None, Some m | Some m, None -> Some m, None
             | Some min, Some max ->
               let abs_min = Z.abs min in
               let abs_max = Z.abs max in
               Some (Z.min abs_min abs_max), Some (Z.max abs_min abs_max)
           in
           let lb = match min_lambda with
             | None -> None
             | Some z ->
               if Z.sign z = -1 then
                 (* the lower bound is (possibly) negative *)
                 Extlib.opt_map2
                   (fun m max ->
                      match min_lambda, max_lambda with
                      | Some mil, Some mal when Z.lt (Z.abs mil) (Z.abs mal) ->
                        (* [lambda] contains both positive and negative values
                           and |mil| < |mal|: instead of [-mal^m], the min is
                           optimized to [mil * mal^(m-1)] *)
                        Z.mul mil (Z.pow max (Z.to_int m - 1))
                      | None, _ | _, None | Some _, Some _ ->
                        Z.neg (Z.pow max (Z.to_int m)))
                   (max_delta minmax_lb minmax_ub)
                   max
               else
                 (* all numbers are positive:
                    the lower bound is necessarily positive *)
                 Option.map
                   (fun m -> Z.pow m (Z.to_int (min_delta minmax_lb minmax_ub)))
                   min
           in
           let ub =
             Extlib.opt_map2
               (fun m max ->
                  match max_lambda with
                  | Some ml when Z.lt ml Z.zero && not (Z.equal m Z.one) ->
                    (* when [lambda] is necessarily negative with an odd number
                       of iterations (>1), the result is necessarily negative,
                       so smaller than the maximal (positive) value. Therefore,
                       it is possible to reduce the number of iteration by 1. *)
                    let exp = Z.to_int m in
                    Z.pow max (exp - exp mod 2)
                  | None | Some _ ->
                    Z.pow max (Z.to_int m))
               (max_delta minmax_lb minmax_ub)
               max
           in
           lb, ub
         | s ->
           Options.fatal "unexpect logic function '%s'" s
       in
       Ival (Ival.inject_range lb ub)
     with
     | Abstract_interp.Error_Bottom -> bottom
     | Z.Overflow (* if the exponent of \product is too high *) -> top_ival)
  | _ -> Error.not_yet "extended quantifiers with non-integer parameters"

let rec infer ~logic_env t =
  let get_cty t = match t.term_type with Ctype ty -> ty | _ -> assert false in
  let get_res = Error.map (fun x -> x) in
  let compute t =
    match t.term_node with
    | TConst (Integer (n, _)) -> singleton n
    | TConst (LChr c) ->
      let n = Cil.charConstToInt c in
      singleton n
    | TConst (LEnum enumitem) ->
      let rec find_idx n = function
        | [] -> assert false
        | ei :: l -> if ei == enumitem then n else find_idx (n + 1) l
      in
      let n = Integer.of_int (find_idx 0 enumitem.eihost.eitems) in
      singleton n
    | TLval lv -> infer_term_lval lv
    | TSizeOf ty -> infer_sizeof ty
    | TSizeOfE t -> infer_sizeof (get_cty t)
    | TSizeOfStr str -> singleton_of_int (String.length str + 1 (* '\0' *))
    | TAlignOf ty -> infer_alignof ty
    | TAlignOfE t -> infer_alignof (get_cty t)

    | TUnOp (Neg, t) ->
      let i = infer ~logic_env t in
      Error.map (lift_unop Ival.neg_int) i
    | TUnOp (BNot, t) ->
      let i = infer ~logic_env t in
      Error.map (lift_unop Ival.bitwise_signed_not) i
    | TUnOp (LNot, t) ->
      ignore(infer ~logic_env t);
      Ival Ival.zero_or_one

    | TBinOp ((Lt | Gt | Le | Ge | Eq | Ne | LAnd | LOr), t1, t2) ->
      ignore(infer ~logic_env t1);
      ignore(infer ~logic_env t2);
      Ival Ival.zero_or_one

    | TBinOp (PlusA, t1, t2) ->
      let i1 = infer ~logic_env t1 in
      let i2 = infer ~logic_env t2 in
      Error.map2 (lift_arith_binop Ival.add_int) i1 i2
    | TBinOp (MinusA, t1, t2) ->
      let i1 = infer ~logic_env t1 in
      let i2 = infer ~logic_env t2 in
      Error.map2 (lift_arith_binop Ival.sub_int) i1 i2
    | TBinOp (Mult, t1, t2) ->
      let i1 = infer ~logic_env t1 in
      let i2 = infer ~logic_env t2 in
      Error.map2 (lift_arith_binop Ival.mul) i1 i2
    | TBinOp (Div, t1, t2) ->
      let i1 = infer ~logic_env t1 in
      let i2 = infer ~logic_env t2 in
      Error.map2 (lift_arith_binop Ival.div) i1 i2
    | TBinOp (Mod, t1, t2) ->
      let i1 = infer ~logic_env t1 in
      let i2 = infer ~logic_env t2 in
      Error.map2 (lift_arith_binop Ival.c_rem) i1 i2
    | TBinOp (Shiftlt, t1, t2) ->
      let i1 = infer ~logic_env t1 in
      let i2 = infer ~logic_env t2 in
      Error.map2 (lift_arith_binop Ival.shift_left) i1 i2
    | TBinOp (Shiftrt, t1, t2) ->
      let i1 = infer ~logic_env t1 in
      let i2 = infer ~logic_env t2 in
      Error.map2 (lift_arith_binop Ival.shift_right) i1 i2
    | TBinOp (BAnd, t1, t2) ->
      let i1 = infer ~logic_env t1 in
      let i2 = infer ~logic_env t2 in
      Error.map2 (lift_arith_binop Ival.bitwise_and) i1 i2
    | TBinOp (BXor, t1, t2) ->
      let i1 = infer ~logic_env t1 in
      let i2 = infer ~logic_env t2 in
      Error.map2 (lift_arith_binop Ival.bitwise_xor) i1 i2
    | TBinOp (BOr, t1, t2) ->
      let i1 = infer ~logic_env t1 in
      let i2 = infer ~logic_env t2 in
      Error.map2 (lift_arith_binop Ival.bitwise_or) i1 i2
    | TCastE (ty, t) ->
      let src = infer ~logic_env t in
      let dst = interv_of_typ ty in
      Error.map (fun src -> cast ~src ~dst) src
    | Tif (_, t2, t3) ->
      let i2 = infer ~logic_env t2 in
      let i3 = infer ~logic_env t3 in
      Error.map2 join i2 i3
    | Tat (t, _) ->
      get_res (infer ~logic_env t)
    | TBinOp (MinusPP, t, _) ->
      (match Cil.unrollType (get_cty t) with
       | TArray(_, _, _) as ta ->
         begin
           try
             let n = Cil.bitsSizeOf ta in
             (* the second argument must be in the same block than [t].
                Consequently the result of the difference belongs to
                [0; \block_length(t)] *)
             let nb_bytes = if n mod 8 = 0 then n / 8 else n / 8 + 1 in
             ival Integer.zero (Integer.of_int nb_bytes)
           with Cil.SizeOfError _ ->
             Lazy.force interv_of_unknown_block
         end
       | TPtr _ -> Lazy.force interv_of_unknown_block
       | _ -> assert false)
    | Tblock_length (_, t)
    | Toffset(_, t) ->
      (match Cil.unrollType (get_cty t) with
       | TArray(_, _, _) as ta ->
         begin
           try
             let n = Cil.bitsSizeOf ta in
             let nb_bytes = if n mod 8 = 0 then n / 8 else n / 8 + 1 in
             singleton_of_int nb_bytes
           with Cil.SizeOfError _ ->
             Lazy.force interv_of_unknown_block
         end
       | TPtr _ -> Lazy.force interv_of_unknown_block
       | _ -> assert false)
    | Tnull  -> singleton_of_int 0
    | TLogic_coerce (_, t) -> get_res (infer ~logic_env t)
    | Tapp (_,_,_) -> assert false

    | Tunion _ -> Error.not_yet "tset union"
    | Tinter _ -> Error.not_yet "tset intersection"
    | Tcomprehension (_,_,_) -> Error.not_yet "tset comprehension"
    | Trange(Some n1, Some n2) ->
      let i1 = infer ~logic_env n1 in
      let i2 = infer ~logic_env n2 in
      Error.map2 join i1 i2
    | Trange(None, _) | Trange(_, None) ->
      Options.abort "unbounded ranges are not part of E-ACSl"

    | Tlet (_,_) -> assert false
    | TConst (LReal lr) ->
      if lr.r_lower = lr.r_upper then Float(FDouble, Some lr.r_nearest)
      else Rational
    | Tlambda ([ _ ],lt) ->
      get_res (infer ~logic_env lt)
    | Tlambda (_,_)
    | TConst (LStr _ | LWStr _)
    | TBinOp (PlusPI,_,_)
    | TBinOp (IndexPI,_,_)
    | TBinOp (MinusPI,_,_)
    | TAddrOf _
    | TStartOf _
    | TDataCons (_,_)
    | Tbase_addr (_,_)
    | TUpdate (_,_,_)
    | Ttypeof _
    | Ttype _
    | Tempty_set ->
      Nan
  in Memo.memo ~profile:(logic_env.profile) compute t

and infer_term_lval (host, offset as tlv) =
  match offset with
  | TNoOffset -> infer_term_host host
  | _ ->
    let ty = Logic_utils.logicCType (Cil.typeOfTermLval tlv) in
    interv_of_typ ty

and infer_term_host thost =
  match thost with
  | TVar v ->
    (try Env.find v with Not_found ->
     match v.lv_type with
     | Linteger -> top_ival
     | Ctype (TFloat(fk, _)) -> Float(fk, None)
     | Lreal -> Real
     | Ctype _ -> interv_of_typ (Logic_utils.logicCType v.lv_type)
     | Ltype _ | Lvar _ | Larrow _ -> Options.fatal "unexpected logic type")
  | TResult ty ->
    interv_of_typ ty
  | TMem t ->
    let ty = Logic_utils.logicCType t.term_type in
    match Cil.unrollType ty with
    | TPtr(ty, _) | TArray(ty, _, _) ->
      interv_of_typ ty
    | _ ->
      Options.fatal "unexpected type %a for term %a"
        Printer.pp_typ ty
        Printer.pp_term t

let infer t =
  let i = infer t in
  Logic_function_env.clear();
  i

include D

let typer_visitor ~logic_env = object
  inherit E_acsl_visitor.visitor dkey

  (* global logic functions and predicates are evaluated are callsites *)
  method !glob_annot _ = Cil.SkipChildren

  method !vterm t =
    (* Do not raise a warning for e-acsl errors at preprocessing time,
       those errrors are stored in the table and warnings are raised at
       translation time*)
    let _ = try ignore (infer ~logic_env t)
      with Error.Not_yet _ | Error.Typing_error _  -> ()
    in
    Cil.SkipChildren
end

let infer_program ast =
  let visitor = typer_visitor ~logic_env:(Logic_environment.create [] []) in
  visitor#visit_file ast

let preprocess_predicate ~logic_env p =
  let visitor = typer_visitor ~logic_env in
  ignore @@ visitor#visit_predicate p

let preprocess_code_annot ~logic_env annot =
  let visitor = typer_visitor ~logic_env in
  ignore @@ visitor#visit_code_annot annot

let preprocess_term ~logic_env t =
  ignore (infer ~logic_env t)

let get_p ~profile t =
  let t = Logic_normalizer.get_term t in
  Error.retrieve_preprocessing
    "Interval inference"
    (Memo.get ~profile)
    t
    Printer.pp_term

let get ~logic_env =
  get_p ~profile:(Logic_environment.get_profile logic_env)

type profile = Profile.t

(*
Local Variables:
compile-command: "make -C ../../../../.."
End:
 *)
