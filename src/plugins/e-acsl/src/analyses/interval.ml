(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2023                                               *)
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
open Analyses_datatype

(* Implements Figure 3 of J. Signoles' JFLA'15 paper "Rester statique pour
   devenir plus rapide, plus précis et plus mince".
   Also implements a support for real numbers. *)
let dkey = Options.Dkey.interval
module Error = Error.Make(struct let phase = dkey end)

(* ********************************************************************* *)
(* Basic datatypes and operations *)
(* ********************************************************************* *)

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

let () = Logic_env.ival_meet_ref := meet

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

exception Not_representable_ival
let ikind_of_ival iv =
  if Ival.is_bottom iv then IInt
  else match Ival.min_and_max iv with
    | Some l, Some u ->
      begin
        try
          let is_pos = Integer.ge l Integer.zero in
          let lkind = Cil.intKindForValue l is_pos in
          let ukind = Cil.intKindForValue u is_pos in
          (* kind corresponding to the interval *)
          let kind = if Cil.intTypeIncluded lkind ukind then ukind else lkind in
          (* convert the kind to [IInt] whenever smaller. *)
          if Cil.intTypeIncluded kind IInt then IInt else kind
        with Cil.Not_representable ->
          raise Not_representable_ival
      end
    | None, None -> raise Not_representable_ival (* GMP *)
    (* TODO: do not raise an exception, but returns a value instead *)
    | None, Some _ | Some _, None ->
      (* Semi-open interval that can happen when computing the interval of shift
         operations if the computation overflows *)
      (* TODO: do not raise an exception, but returns a value instead *)
      raise Not_representable_ival (* GMP *)


let interv_of_typ_containing_interv = function
  | Float _ | Rational | Real | Nan as x ->
    x
  | Ival i ->
    try
      let kind = ikind_of_ival i in
      interv_of_typ (TInt(kind, []))
    with Not_representable_ival ->
      top_ival

let widen_profile =
  Cil_datatype.Logic_var.Map.map interv_of_typ_containing_interv

let rec fixpoint ~(infer : force:bool ->
                   logic_env:Logic_env.t ->
                   term ->
                   ival Error.result)
    li args_ival t' ival =
  let get_res = Error.map (fun x -> x) in
  let logic_env = Logic_env.make args_ival in
  (* If the logic function has a given C type, we use this type to infer the
     interval. Otherwise we compute this interval as a fixpoint *)
  match li.l_type with
  | Some (Ctype typ) ->
    let ival = interv_of_typ typ in
    LF_env.add li args_ival ival;
    ignore (infer ~force:true ~logic_env t');
    ival
  | None | Some (Linteger | Lreal | Ltype _ | Lvar _ | Larrow _) ->
    LF_env.replace li args_ival ival;
    let inferred_ival = get_res (infer ~force:true ~logic_env t') in
    if is_included inferred_ival ival
    then
      ival
    else
      let assumed_ival = interv_of_typ_containing_interv inferred_ival in
      fixpoint ~infer li args_ival t' assumed_ival

(* Memoization module which retrieves the computed info of some terms *)
module Memo: sig
  val memo:
    force_infer:bool -> Profile.t -> (term -> ival) -> term -> ival Error.result
  val get: Profile.t -> term -> ival Error.result
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
  let nondep_tbl : ival Error.result Misc.Id_term.Hashtbl.t =
    Misc.Id_term.Hashtbl.create 97

  (* The interval of the logic function
     //@ logic integer f (integer x) = x + 1;
     depends on the interval of [x]. The same term [x+1] can be infered to be
     in different intervals if the function [f] is applied several times with
     different arguments. In this case, we add the interval of [x] as a key
     to retrieve the type of [x+1].
     There are two other kinds of binders for logical variables: [TLet] and
     the quantifiers, however in those cases, a term is only ever translated
     once. *)

  let dep_tbl : ival Error.result Id_term_in_profile.Hashtbl.t
    = Id_term_in_profile.Hashtbl.create 97

  (* Small functor to access the result of a memoized inference *)
  module Accesses (X : Datatype.S_with_collections)
      (Tbl: sig val tbl : ival Error.result X.Hashtbl.t end)
    : sig
      val get : X.Hashtbl.key -> ival Error.result
      val memo : force_infer:bool -> (term -> ival) -> term -> X.Hashtbl.key ->
        (ival, exn) Result.t
    end = struct
    let get k =
      try X.Hashtbl.find Tbl.tbl k
      with Not_found -> Error.not_memoized ()

    let memo ~force_infer f t k =
      if force_infer then
        let x =
          try Result.Ok (f t);
          with Error.Not_yet _ | Error.Typing_error _ as exn -> Result.Error exn
        in
        X.Hashtbl.replace Tbl.tbl k x;
        x
      else
        try X.Hashtbl.find Tbl.tbl k
        with Not_found ->
          let x =
            try Result.Ok (f t);
            with Error.Not_yet _ | Error.Typing_error _ as exn -> Result.Error exn
          in
          X.Hashtbl.add Tbl.tbl k x;
          x
  end

  module Nondep = Accesses (Misc.Id_term) (struct let tbl = nondep_tbl end)
  module Dep = Accesses (Id_term_in_profile) (struct let tbl = dep_tbl end)

  let get profile t =
    if Profile.is_empty profile
    then Nondep.get t
    else Dep.get (t,profile)

  let memo ~force_infer profile f t =
    if Profile.is_empty profile
    then Nondep.memo ~force_infer f t t
    else Dep.memo ~force_infer f t (t,profile)

  let clear () =
    Options.feedback ~level:4 "clearing the typing tables";
    Misc.Id_term.Hashtbl.clear nondep_tbl;
    Id_term_in_profile.Hashtbl.clear dep_tbl
end

(* For recursive functions, it is necessary to use a widened profile to query
   the table (because of the fixpoint algorithm). This module associates to a
   term in a profile, the profile that should be used to query the table *)
module Widened_profile: sig
  val get: Profile.t -> logic_info -> Profile.t
  val add: Profile.t -> logic_info -> Profile.t -> unit
  val clear: unit -> unit
end = struct

  let widened_profile_tbl : Profile.t LFProf.Hashtbl.t
    = LFProf.Hashtbl.create 97

  let get profile li =
    LFProf.Hashtbl.find_def widened_profile_tbl (li, profile) profile

  let add profile i args_ival =
    LFProf.Hashtbl.add widened_profile_tbl (i, profile) args_ival

  let clear () =
    Options.feedback ~level:4 "clearing the typing tables";
    LFProf.Hashtbl.clear widened_profile_tbl
end

let plus_one i =
  lift_arith_binop Ival.add_int i (singleton Integer.one)

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

let rec infer ~force ~logic_env t =
  let get_cty t = match t.term_type with Ctype ty -> ty | _ -> assert false in
  let get_res = Error.map (fun x -> x) in
  let t = Logic_normalizer.get_term t in
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
    | TLval lv -> infer_term_lval ~force ~logic_env lv
    | TSizeOf ty -> infer_sizeof ty
    | TSizeOfE t ->
      ignore (infer ~force ~logic_env t);
      infer_sizeof (get_cty t)
    | TSizeOfStr str -> singleton_of_int (String.length str + 1 (* '\0' *))
    | TAlignOf ty -> infer_alignof ty
    | TAlignOfE t ->
      ignore (infer ~force ~logic_env t);
      infer_alignof (get_cty t)

    | TUnOp (Neg, t) ->
      let i = infer ~force ~logic_env t in
      Error.map (lift_unop Ival.neg_int) i
    | TUnOp (BNot, t) ->
      let i = infer ~force ~logic_env t in
      Error.map (lift_unop Ival.bitwise_signed_not) i
    | TUnOp (LNot, t) ->
      ignore (infer ~force ~logic_env t);
      Ival Ival.zero_or_one

    | TBinOp ((Lt | Gt | Le | Ge | Eq | Ne | LAnd | LOr), t1, t2) ->
      ignore (infer ~force ~logic_env t1);
      ignore (infer ~force ~logic_env t2);
      Ival Ival.zero_or_one

    | TBinOp (PlusA, t1, t2) ->
      let i1 = infer ~force ~logic_env t1 in
      let i2 = infer ~force ~logic_env t2 in
      Error.map2 (lift_arith_binop Ival.add_int) i1 i2
    | TBinOp (MinusA, t1, t2) ->
      let i1 = infer ~force ~logic_env t1 in
      let i2 = infer ~force ~logic_env t2 in
      Error.map2 (lift_arith_binop Ival.sub_int) i1 i2
    | TBinOp (Mult, t1, t2) ->
      let i1 = infer ~force ~logic_env t1 in
      let i2 = infer ~force ~logic_env t2 in
      Error.map2 (lift_arith_binop Ival.mul) i1 i2
    | TBinOp (Div, t1, t2) ->
      let i1 = infer ~force ~logic_env t1 in
      let i2 = infer ~force ~logic_env t2 in
      Error.map2 (lift_arith_binop Ival.div) i1 i2
    | TBinOp (Mod, t1, t2) ->
      let i1 = infer ~force ~logic_env t1 in
      let i2 = infer ~force ~logic_env t2 in
      Error.map2 (lift_arith_binop Ival.c_rem) i1 i2
    | TBinOp (Shiftlt, t1, t2) ->
      let i1 = infer ~force ~logic_env t1 in
      let i2 = infer ~force ~logic_env t2 in
      Error.map2 (lift_arith_binop Ival.shift_left) i1 i2
    | TBinOp (Shiftrt, t1, t2) ->
      let i1 = infer ~force ~logic_env t1 in
      let i2 = infer ~force ~logic_env t2 in
      Error.map2 (lift_arith_binop Ival.shift_right) i1 i2
    | TBinOp (BAnd, t1, t2) ->
      let i1 = infer ~force ~logic_env t1 in
      let i2 = infer ~force ~logic_env t2 in
      Error.map2 (lift_arith_binop Ival.bitwise_and) i1 i2
    | TBinOp (BXor, t1, t2) ->
      let i1 = infer ~force ~logic_env t1 in
      let i2 = infer ~force ~logic_env t2 in
      Error.map2 (lift_arith_binop Ival.bitwise_xor) i1 i2
    | TBinOp (BOr, t1, t2) ->
      let i1 = infer ~force ~logic_env t1 in
      let i2 = infer ~force ~logic_env t2 in
      Error.map2 (lift_arith_binop Ival.bitwise_or) i1 i2
    | TCastE (ty, t) ->
      let src = infer ~force ~logic_env t in
      let dst = interv_of_typ ty in
      Error.map (fun src -> cast ~src ~dst) src
    | Tif (t1, t2, t3) ->
      ignore (infer ~force ~logic_env t1);
      let logic_env_tbranch, logic_env_fbranch =
        compute_logic_env_if_branches logic_env t1
      in
      let i2 = infer ~force ~logic_env:logic_env_tbranch t2 in
      let i3 = infer ~force ~logic_env:logic_env_fbranch t3 in
      Error.map2 join i2 i3
    | Tat (t, _) ->
      get_res (infer ~force ~logic_env t)
    | TBinOp (MinusPP, t1, t2) ->
      ignore (infer ~force ~logic_env t1);
      ignore (infer ~force ~logic_env t2);
      (match Cil.unrollType (get_cty t1) with
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
      ignore (infer ~force ~logic_env t);
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
    | TLogic_coerce (_, t) -> get_res (infer ~force ~logic_env t)
    | Tapp (li,_,args) ->
      (match li.l_body with
       | LBpred _ | LBterm _ ->
         let profile =
           Profile.make
             li.l_profile
             (List.map
                (fun arg -> get_res (infer ~force ~logic_env arg))
                args)
         in
         if LF_env.is_rec li then
           let widened_profile = widen_profile profile in
           Widened_profile.add profile li widened_profile;
           try LF_env.find li widened_profile
           with
           | Not_found ->
             (match li.l_body with
              | LBpred p ->
                LF_env.add_pred li widened_profile;
                infer_predicate
                  ~logic_env:(Logic_env.make widened_profile) p;
                Ival Ival.zero_or_one
              | LBterm t' ->
                fixpoint ~infer li widened_profile t' (Ival Ival.bottom)
              | _ -> assert false)
         else
           let logic_env = Logic_env.make profile in
           (match li.l_body with
            | LBpred p ->
              ignore (infer_predicate ~logic_env p);
              Ival Ival.zero_or_one
            | LBterm t' ->
              (* If the logic function returns a C type, then its application
                 ranges inside this C type *)
              (match li.l_type with
               | Some (Ctype typ) ->
                 ignore ((infer ~force ~logic_env t'));
                 interv_of_typ typ;
               | None | Some (Linteger | Lreal | Ltype _ | Lvar _ | Larrow _) ->
                 get_res (infer ~force ~logic_env t'))
            | _ -> assert false)
       | LBnone when li.l_var_info.lv_name = "\\sum" ||
                     li.l_var_info.lv_name = "\\product" ->
         (match args with
          | [ t1; t2; { term_node = Tlambda([ k ], _) } as lambda ] ->
            let t1_iv = infer ~force ~logic_env t1 in
            let t2_iv = infer ~force ~logic_env t2 in
            let k_iv = Error.map2 join t1_iv t2_iv in
            let logic_env_with_k =
              Logic_env.add logic_env k k_iv
            in
            let lambda_iv = infer ~force ~logic_env:logic_env_with_k lambda in
            Error.map3 (infer_sum_product li.l_var_info) lambda_iv t1_iv t2_iv
          | _ -> Error.not_yet "extended quantifiers without lambda term")
       | LBnone
       | LBreads _ ->
         List.iter
           (fun arg -> ignore (infer ~force ~logic_env arg))
           args;
         (match li.l_type with
          | None -> assert false
          | Some ret_type -> interv_of_logic_typ ret_type)
       | LBinductive _ ->
         Error.not_yet "logic functions inductively defined")

    | Tunion _ -> Error.not_yet "tset union"
    | Tinter _ -> Error.not_yet "tset intersection"
    | Tcomprehension (_,_,_) -> Error.not_yet "tset comprehension"
    | Trange(Some n1, Some n2) ->
      let i1 = infer ~force ~logic_env n1 in
      let i2 = infer ~force ~logic_env n2 in
      Error.map2 join i1 i2
    | Trange(None, _) | Trange(_, None) ->
      Options.abort ~current:true "unbounded ranges are not part of E-ACSl"

    | Tlet (li,t) ->
      let li_t = Misc.term_of_li li in
      let li_v = li.l_var_info in
      let i1 = infer ~force ~logic_env li_t in
      let logic_env =
        Error.map (Logic_env.add logic_env li_v) i1
      in
      get_res (infer ~force ~logic_env t)
    | TConst (LReal lr) ->
      if lr.r_lower = lr.r_upper then Float(FDouble, Some lr.r_nearest)
      else Rational
    | Tlambda ([ _ ],lt) ->
      get_res (infer ~force ~logic_env lt)

    | TStartOf lv
    | TAddrOf lv ->
      ignore (infer_term_lval ~force ~logic_env lv);
      Nan

    | TBinOp (PlusPI, t1 ,t2)
    | TBinOp (MinusPI, t1, t2) ->
      ignore (infer ~force ~logic_env t1);
      ignore (infer ~force ~logic_env t2);
      Nan

    | Tbase_addr (_,t)
    | Ttypeof t ->
      ignore (infer ~force ~logic_env t);
      Nan

    |TDataCons(_,l) ->
      List.iter (fun t -> ignore (infer ~force ~logic_env t)) l;
      Nan

    | TUpdate(t1, toff, t2) ->
      ignore (infer ~force ~logic_env t1);
      ignore (infer ~force ~logic_env t2);
      infer_term_offset ~force ~logic_env toff;
      Nan

    | Tlambda (_,_)
    | TConst (LStr _ | LWStr _)
    | Ttype _
    | Tempty_set ->
      Nan
  in
  Memo.memo
    ~force_infer:force
    (Logic_env.get_profile logic_env)
    compute
    t

and infer_term_lval ~force ~logic_env (host, offset as tlv) =
  match offset with
  | TNoOffset -> infer_term_host ~force ~logic_env host
  | _ ->
    ignore (infer_term_host ~force ~logic_env host);
    infer_term_offset ~force ~logic_env offset;
    let ty = Logic_utils.logicCType (Cil.typeOfTermLval tlv) in
    interv_of_typ ty

and infer_term_host ~force ~logic_env thost =
  match thost with
  | TVar v ->
    (try Logic_env.find logic_env v with Not_found ->
     match v.lv_type with
     | Linteger -> top_ival
     | Ctype (TFloat(fk, _)) -> Float(fk, None)
     | Lreal -> Real
     | Ctype _ -> interv_of_typ (Logic_utils.logicCType v.lv_type)
     | Ltype _ | Lvar _ | Larrow _ -> Options.fatal "unexpected logic type")
  | TResult ty ->
    interv_of_typ ty
  | TMem t ->
    ignore (infer ~force ~logic_env t);
    let ty = Logic_utils.logicCType t.term_type in
    match Cil.unrollType ty with
    | TPtr(ty, _) | TArray(ty, _, _) ->
      interv_of_typ ty
    | _ ->
      Options.fatal "unexpected type %a for term %a"
        Printer.pp_typ ty
        Printer.pp_term t

and infer_term_offset ~force ~logic_env t =
  match t with
  | TNoOffset -> ()
  | TField(_, toff)
  | TModel(_, toff) -> infer_term_offset ~force ~logic_env toff
  | TIndex(t, toff) ->
    ignore (infer ~force ~logic_env t);
    infer_term_offset ~force ~logic_env toff

(* Update the interval of variables when they appear in a comparison of the form
   [x op t] or [t op x] *)
and compute_logic_env_if_branches logic_env t =
  let get_res = Error.map (fun x -> x) in
  let ival v = infer ~force:false ~logic_env v in
  let add_ub logic_env x v =
    let max = Ival.max_int (Error.map extract_ival (ival v)) in
    Logic_env.refine logic_env x (Ival (Ival.inject_range None max))
  in
  let add_lb logic_env x v =
    let min = Ival.min_int (Error.map extract_ival (ival v)) in
    Logic_env.refine logic_env x (Ival (Ival.inject_range min None))
  in
  let add_eq logic_env x v = Logic_env.refine logic_env x (get_res (ival v)) in
  let t_branch, f_branch =
    (* we do not discriminate between strict and weak inequalities. This is
       slighlty less precise but allow for better reusing of the code in the
       case of recursive functions, the main advantage in typing
       conditionals is for recursive functions. *)
    match t.term_node with
    | TBinOp(op, {term_node = TLval(TVar x, TNoOffset)}, v) ->
      begin
        match op with
        | Lt | Le ->
          add_ub logic_env x v,
          add_lb logic_env x v
        | Gt | Ge ->
          add_lb logic_env x v,
          add_ub logic_env x v
        | Eq ->
          add_eq logic_env x v,
          logic_env
        | Ne ->
          logic_env,
          add_eq logic_env x v
        | _ -> logic_env, logic_env
      end
    | _ -> logic_env, logic_env
  in
  match t.term_node with
  | TBinOp(op, u, {term_node = TLval(TVar y, TNoOffset)}) ->
    begin
      match op with
      | Lt | Le ->
        add_lb t_branch y u,
        add_ub f_branch y u
      | Gt | Ge ->
        add_ub t_branch y u,
        add_lb f_branch y u
      | Eq ->
        add_eq t_branch y u,
        logic_env
      | Ne ->
        logic_env,
        add_eq f_branch y u
      | _ -> t_branch, f_branch
    end
  | _ -> t_branch, f_branch

(* [type_bound_variables] infers an interval associated with each of
   the provided bounds of a quantified variable, and provides a term
   accordingly. It could happen that the bounds provided for a quantifier
   [lv] are bigger than its type. [type_bound_variables] handles such cases
   and provides smaller bounds whenever possible.
   Let B be the inferred interval and R the range of [lv.typ]
   - Case 1: B \subseteq R
     Example: [\forall unsigned char c; 4 <= c <= 100 ==> 0 <= c <= 255]
     Return: B
   - Case 2: B \not\subseteq R and the bounds of B are inferred exactly
     Example: [\forall unsigned char c; 4 <= c <= 300 ==> 0 <= c <= 255]
     Return: B \intersect R
   - Case 3: B \not\subseteq R and the bounds of B are NOT inferred exactly
     Example: [\let m = n > 0 ? 4 : 341; \forall char u; 1 < u < m ==> u > 0]
     Return: R with a guard guaranteeing that [lv] does not overflow *)
and infer_bound_variable ~loc ~logic_env (t1, lv, t2) =
  let get_res = Error.map (fun x -> x) in
  let i1 = get_res (infer ~force:false ~logic_env t1) in
  let i2 = get_res (infer ~force:false ~logic_env t2) in
  let i = widen (join i1 i2) in
  let t1, t2, i =
    match lv.lv_type with
    | Ltype _ | Lvar _ | Lreal | Larrow _ ->
      Error.not_yet "quantification over non-integer type"
    | Linteger -> t1, t2, i
    | Ctype ty ->
      let ity = extended_interv_of_typ ty in
      if is_included i ity then
        (* case 1 *)
        t1, t2, i
      else if is_singleton_int i1 &&
              is_singleton_int i2 then
        begin
          (* case 2 *)
          let i = meet i ity in
          (* We can now update the bounds in the preprocessed form
             that come from the meet of the two intervals *)
          let min, max = Misc.finite_min_and_max (extract_ival i) in
          let t1 = Logic_const.tint ~loc min in
          let t2 = Logic_const.tint ~loc max in
          t1, t2, i
        end else
        (* case 3 *)
        let min, max = Misc.finite_min_and_max (extract_ival ity) in
        let guard_lower = Logic_const.tint ~loc min in
        let guard_upper = Logic_const.tint ~loc max in
        let lv_term = Logic_const.tvar ~loc lv in
        let guard_lower = Logic_const.prel ~loc (Rle, guard_lower, lv_term) in
        let guard_upper = Logic_const.prel ~loc (Rlt, lv_term, guard_upper) in
        let guard = Logic_const.pand ~loc (guard_lower, guard_upper) in
        ignore (infer_predicate ~logic_env guard);
        Bound_variables.add_guard_for_small_type lv guard;
        t1, t2, i
  in
  ignore (infer ~force:false ~logic_env t1);
  ignore (infer ~force:false ~logic_env t2);
  Logic_env.add logic_env lv i, (t1, lv, t2)

and infer_predicate ~logic_env p =
  let get_res = Error.map (fun x -> x) in
  let p = Logic_normalizer.get_pred p in
  match p.pred_content with
  | Pfalse | Ptrue -> ()
  | Papp(li, _, args) ->
    let profile =
      Profile.make
        li.l_profile
        (List.map
           (fun arg -> get_res (infer ~force:false ~logic_env arg))
           args)
    in
    (match li.l_body with
     | LBpred p when LF_env.is_rec li ->
       let widened_profile = widen_profile profile in
       Widened_profile.add profile li widened_profile;
       (try ignore (LF_env.find li widened_profile)
        with Not_found ->
          LF_env.add_pred li widened_profile;
          infer_predicate ~logic_env:(Logic_env.make widened_profile) p)
     | LBpred p ->
       let logic_env = Logic_env.make profile in
       ignore (infer_predicate ~logic_env p)
     | LBnone -> ()
     | LBreads _ -> ()
     | LBinductive _ -> ()
     | LBterm _ ->
       Options.fatal "unexpected logic definition"
         Printer.pp_predicate p
    )
  | Pdangling _ -> ()
  | Prel(_, t1, t2) ->
    ignore (infer ~force:false ~logic_env t1);
    ignore (infer ~force:false ~logic_env t2)
  | Pand(p1, p2)
  | Por(p1, p2)
  | Pxor(p1, p2)
  | Pimplies(p1, p2)
  | Piff(p1, p2) ->
    infer_predicate ~logic_env p1;
    infer_predicate ~logic_env p2
  | Pnot p ->
    infer_predicate ~logic_env p;
  | Pif(t, p1, p2) ->
    ignore (infer ~force:false ~logic_env t);
    let logic_env_tbranch, logic_env_fbranch =
      compute_logic_env_if_branches logic_env t
    in
    infer_predicate ~logic_env:logic_env_tbranch p1;
    infer_predicate ~logic_env:logic_env_fbranch p2
  | Plet(li, p) ->
    let li_t = Misc.term_of_li li in
    let li_v = li.l_var_info in
    let i = infer ~force:false ~logic_env li_t in
    let logic_env =
      Error.map (Logic_env.add logic_env li_v) i
    in
    infer_predicate ~logic_env p
  | Pforall _
  | Pexists _ ->
    let guards, goal =
      Error.retrieve_preprocessing
        "quantified predicate"
        Bound_variables.get_preprocessed_quantifier
        p
        Printer.pp_predicate
    in
    let loc = p.pred_loc in
    let rec do_analysis guards new_guards logic_env =
      match guards with
      | [] -> logic_env, new_guards
      | guard :: guards ->
        let  logic_env, new_guard =
          infer_bound_variable ~loc ~logic_env guard
        in
        do_analysis guards (new_guard :: new_guards) logic_env
    in
    let logic_env, new_guards = do_analysis guards [] logic_env in
    Bound_variables.replace p new_guards goal;
    infer_predicate ~logic_env goal
  | Pseparated tlist ->
    List.iter
      (fun t -> ignore (infer ~force:false ~logic_env t))
      tlist;
  | Pinitialized(_, t)
  | Pfreeable(_, t)
  | Pallocable(_, t)
  | Pvalid(_, t)
  | Pvalid_read(_, t)
  | Pobject_pointer(_,t)
  | Pvalid_function t ->
    ignore (infer ~force:false ~logic_env t);
  | Pat(p, _) -> infer_predicate ~logic_env p
  | Pfresh _ -> Error.not_yet "\\fresh"

let infer t =
  let i = infer t in
  i

include Ival_datatype

let typer_visitor ~logic_env = object
  inherit E_acsl_visitor.visitor dkey

  (* global logic functions and predicates are evaluated are callsites *)
  method !glob_annot _ = Cil.SkipChildren

  method !vpredicate p =
    (* Do not raise a warning for e-acsl errors at preprocessing time,
       those errrors are stored in the table and warnings are raised at
       translation time *)
    (try infer_predicate ~logic_env p
     with Error.Not_yet _ | Error.Typing_error _  -> ());
    Cil.SkipChildren
end

let infer_program ast =
  let visitor = typer_visitor ~logic_env:Logic_env.empty in
  visitor#visit_file ast

let preprocess_predicate ~logic_env p =
  let visitor = typer_visitor ~logic_env in
  ignore @@ visitor#visit_predicate p

let preprocess_code_annot ~logic_env annot =
  let visitor = typer_visitor ~logic_env in
  ignore @@ visitor#visit_code_annot annot

let preprocess_term ~logic_env t =
  ignore (infer ~force:false ~logic_env t)

let get_from_profile ~profile t =
  let t = Logic_normalizer.get_term t in
  Error.retrieve_preprocessing
    "Interval inference"
    (Memo.get profile)
    t
    Printer.pp_term

let get ~logic_env =
  get_from_profile ~profile:(Logic_env.get_profile logic_env)

let get_widened_profile = Widened_profile.get

let clear () =
  Memo.clear();
  Widened_profile.clear();
  LF_env.clear()

(*
Local Variables:
compile-command: "make -C ../../../../.."
End:
 *)
