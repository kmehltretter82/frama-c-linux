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

include Datatype.Rational
type scalar = t

let zero = Q.zero
let one = Q.one
let two = Q.of_int 2
let ten = Z.of_int 10
let pos_inf = Q.inf
let neg_inf = Q.minus_inf
let of_float = Q.of_float
let to_float = Q.to_float
let of_int = Q.of_int

let pow10 e = Z.(pow ten e) |> Q.of_bigint

let split_significant_exponent s =
  match String.split_on_char 'e' s with
  | [] | _ :: _ :: _ :: _ -> assert false
  | [ s ] -> s, 0
  | [ m ; e ] -> m, int_of_string e

let significant_of_string significant =
  match String.split_on_char '.' significant with
  | [] | _ :: _ :: _ :: _ -> assert false
  | [ m ] -> Q.of_string m
  | [ integer ; fractional ] ->
    let shift = pow10 (String.length fractional) in
    Q.(of_string (integer ^ fractional) / shift)

let of_string str =
  let str = String.lowercase_ascii str in
  let length = String.length str in
  let last = String.get str (length - 1) in
  let str = if last == 'f' then String.sub str 0 (length - 1) else str in
  let significant, e = split_significant_exponent str in
  let significant = significant_of_string significant in
  let shift = if e >= 0 then pow10 e else Q.inv (pow10 ~-e) in
  Q.(significant * shift)

let pow2 e =
  Q.(mul_2exp one e)

(* r = ⌊log₂ (n / d)⌋ = ⌊log₂ n - log₂ d⌋ which cannot be calculated directly.
   However, we have the three following properties:
   - ⌊x⌋ + ⌊y⌋ ≤ ⌊x + y⌋ ≤ ⌊x⌋ + ⌊y⌋ + 1 ;
   - ⌊-x⌋ = -⌈x⌉ ;
   - ⌈x⌉ = ⌊x⌋ + 1 ;
     Thus, we deduce that ⌊log₂ n⌋ - ⌊log₂ d⌋ - 1 ≤ r ≤ ⌊log₂ n⌋ - ⌊log₂ d⌋. *)
let log2 q =
  if Q.(q <= zero) then raise (Invalid_argument (Q.to_string q)) ;
  let num = Q.num q |> Z.log2 and den = Q.den q |> Z.log2 in
  Field.{ lower = num - den - 1 ; upper = num - den }

let neg = Q.neg
let abs = Q.abs
let min = Q.min
let max = Q.max

let sqrt q =
  if Q.sign q = 1 then
    let num = Q.num q and den = Q.den q in
    let acceptable_delta = Q.inv (Q.of_bigint @@ Z.pow ten 32) in
    let rec approx_starting_at_scaling scaling =
      let lower = Z.(sqrt (num * den * scaling * scaling)) in
      let upper = Z.(lower + one) in
      let denominator = Z.(den * scaling) in
      let lower = Q.(make lower denominator) in
      let upper = Q.(make upper denominator) in
      let delta = Q.(upper - lower) in
      if Q.(delta <= acceptable_delta) then Field.{ lower ; upper }
      else approx_starting_at_scaling Z.(scaling * scaling)
    in approx_starting_at_scaling ten
  else { lower = neg_inf ; upper = pos_inf }

let ( + ) = Q.( + )
let ( - ) = Q.( - )
let ( * ) = Q.( * )
let ( / ) = Q.( / )

let ( =  ) l r = Q.equal l r
let ( != ) l r = not (l = r)
let ( <= ) = Q.( <= )
let ( <  ) = Q.( <  )
let ( >= ) = Q.( >= )
let ( >  ) = Q.( >  )
