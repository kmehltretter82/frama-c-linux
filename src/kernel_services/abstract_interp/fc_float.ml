(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2025                                               *)
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

open Float_sig



type rounding = Floating_point.rounding
type context = Floating_point.resulting_format * rounding

let format_of_prec = function
  | Single -> Floating_point.Format Single
  | Double | Long_Double | Real -> Floating_point.Format Double

let convert_rounding = function
  | Float_sig.Up   -> Floating_point.Upward
  | Float_sig.Down -> Floating_point.Downward
  | Float_sig.Near -> Floating_point.Nearest_even
  | Float_sig.Zero -> Floating_point.Toward_zero

let using ~prec ~rounding = (format_of_prec prec, convert_rounding rounding)

let ( let<> ) ((format, new_rounding) : context) computation =
  let old_rounding = Floating_point.get_rounding_mode () in
  Floating_point.set_rounding_mode new_rounding ;
  let result = computation format in
  Floating_point.set_rounding_mode old_rounding ;
  result



type t = float
let hash = Hashtbl.hash
let packed_descr = Structural_descr.p_float
let pretty fmt f = Floating_point.(pretty fmt (double f))

let is_exact = function
  | Single | Double -> true
  | Long_Double | Real -> false

let of_float rounding prec f =
  let<> Format fmt = using ~prec ~rounding in
  Floating_point.(of_float fmt f |> to_float)

let to_float f = f

let round_to_precision round prec t =
  of_float round prec t



(** NOTE: all floating-point comparisons using OCaml's standard operators
    do NOT distinguish between -0.0 and 0.0.
    Whenever floats are compared using them, it implies that negative zeroes
    are also considered, e.g. "if x < 0.0" is equivalent to "if x < -0.0",
    which is also equivalent to "F.compare x (-0.0) < 0".
    This 'total_compare' operator distinguishes -0. and 0. *)
external total_compare : float -> float -> int = "float_compare_total" [@@noalloc]

let cmp_ieee = (compare: float -> float -> int)
let compare = total_compare

let is_nan a = classify_float a = FP_nan
let is_infinite f = classify_float f = FP_infinite

let is_finite f =
  match classify_float f with
  | FP_nan | FP_infinite -> false
  | FP_normal | FP_subnormal | FP_zero -> true

external is_negative : float -> bool = "float_is_negative" [@@noalloc]



(* Wrong for [next -0.] and [prev 0.], as this function uses the binary
   representation of floating-point values, which is not continuous at 0. *)
let next_previous int64fup int64fdown float =
  let r = Int64.bits_of_float float in
  let f = if r >= 0L then int64fup else int64fdown in
  let f = Int64.float_of_bits (f r) in
  match classify_float f with
  | FP_nan -> float (* can only be produced from an infinity or a nan *)
  | FP_infinite | FP_normal | FP_subnormal | FP_zero -> f

let next_float prec f =
  if is_exact prec then
    if compare f (-0.) <> 0 then
      let f = next_previous Int64.succ Int64.pred f in
      round_to_precision Up prec f
    else 0.
  else f

let prev_float prec f =
  if is_exact prec then
    if compare f 0. <> 0 then
      let f = next_previous Int64.pred Int64.succ f in
      round_to_precision Down prec f
    else -0.
  else f

let widen_up ?(hint = Datatype.Float.Set.empty) prec f =
  let is_upper e = total_compare e f >= 0 in
  match Datatype.Float.Set.find_first_opt is_upper hint with
  | None -> if f <= max_float then max_float else infinity
  | Some result -> round_to_precision Up prec result

let widen_down ?(hint = Datatype.Float.Set.empty) prec f =
  let is_lower e = total_compare e f <= 0 in
  match Datatype.Float.Set.find_last_opt is_lower hint with
  | None -> if f >= -.max_float then -.max_float else neg_infinity
  | Some result -> round_to_precision Down prec result



let neg = (~-.)
let abs = abs_float
let floor = floor
let ceil  = ceil

let trunc  f = Floating_point.(double f |> trunc |> to_float)
let fround f = Floating_point.(single f |> round |> to_float)

type 'f number = 'f Floating_point.t
type unary = { compute : 'f. 'f number -> 'f number }
type binary = { compute : 'f. 'f number -> 'f number -> 'f number }

let unary (op : unary) rounding prec x =
  let<> Format fmt = using ~prec ~rounding in
  Floating_point.(op.compute (of_float fmt x) |> to_float)

let binary (op : binary) rounding prec x y =
  let<> Format fmt = using ~prec ~rounding in
  Floating_point.(op.compute (of_float fmt x) (of_float fmt y) |> to_float)

let add  = binary { compute = Floating_point.( + ) }
let sub  = binary { compute = Floating_point.( - ) }
let mul  = binary { compute = Floating_point.( * ) }
let div  = binary { compute = Floating_point.( / ) }
let fmod = binary { compute = Floating_point.fmod }

let exp   = unary { compute = Floating_point.exp }
let log   = unary { compute = Floating_point.log }
let log10 = unary { compute = Floating_point.log10 }
let sqrt  = unary { compute = Floating_point.sqrt }
let pow   = binary { compute = Floating_point.pow }

let cos   = unary { compute = Floating_point.cos }
let sin   = unary { compute = Floating_point.sin }
let tan   = unary { compute = Floating_point.tan }
let acos  = unary { compute = Floating_point.acos }
let asin  = unary { compute = Floating_point.asin }
let atan  = unary { compute = Floating_point.atan }
let atan2 = binary { compute = Floating_point.atan2 }
