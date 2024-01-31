(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2023                                               *)
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



module Rational = struct

  type scalar = Q.t

  module Type = struct
    include Datatype.Serializable_undefined
    type t = scalar
    let name = "Linear.Filter.Test.Rational"
    let reprs = [ Q.zero ]
    let compare = Q.compare
    let equal = Q.equal
    let hash q = Z.hash (Q.num q) + 11 * Z.hash (Q.den q)
  end

  include Datatype.Make_with_collections (Type)

  let pretty fmt n =
    let ten = Z.of_int 10 in
    let sign = if Q.sign n >= 0 then "" else "-" in
    let num = Q.num n |> Z.abs and den = Q.den n |> Z.abs in
    let finish n = Z.Compare.(n >= den || n == Z.zero) in
    let rec f e n = if finish n then (n, e) else f (e + 1) Z.(n * ten) in
    let num, exponent = f 0 num in
    let default fmt n = Format.fprintf fmt "%1.7f" (Q.to_float n) in
    if exponent > 0 then
      let number = Q.make num den in
      Format.fprintf fmt "%s%aE-%d" sign default number exponent
    else default fmt n

  include Q
  let infinity = Q.inf
  let ( == ) = Q.equal

end



module Filter = Linear_filter.Make (Rational)
module Linear = Filter.Linear

let max_exponent = 200
let fin size n = Finite.of_int size n |> Option.get
let set row col i j n = Linear.Matrix.set (fin row i) (fin col j) n

let pretty_invariant fmt = function
  | None -> Format.fprintf fmt "%s" (Unicode.top_string ())
  | Some invariant -> Format.fprintf fmt "%a" Rational.pretty invariant



module Circle = struct

  let order = Nat.(succ one)

  let state =
    Linear.Matrix.zero order order
    |> set order order 0 0 Rational.(of_float 0.68)
    |> set order order 0 1 Rational.(of_float ~-.0.68)
    |> set order order 1 0 Rational.(of_float 0.68)
    |> set order order 1 1 Rational.(of_float 0.68)

  let input = Linear.Matrix.id order

  let measure = Linear.Vector.repeat Rational.one order

  let compute () =
    let filter = Filter.create state input measure in
    let invariant = Filter.invariant filter max_exponent in
    Kernel.result "Circle : %a@." pretty_invariant invariant

end



module Simple = struct

  let order = Nat.(succ one)
  let delay = Nat.one

  let state =
    Linear.Matrix.zero order order
    |> set order order 0 0 Rational.(of_float 1.5)
    |> set order order 0 1 Rational.(of_float ~-.0.7)
    |> set order order 1 0 Rational.(of_float 1.)
    |> set order order 1 1 Rational.(of_float 0.)

  let input =
    Linear.Matrix.zero order delay
    |> set order delay 0 0 Rational.one
    |> set order delay 1 0 Rational.zero

  let measure = Linear.Vector.repeat (Rational.of_float 0.1) delay

  let compute () =
    let filter = Filter.create state input measure in
    let invariant = Filter.invariant filter max_exponent in
    Kernel.result "Simple : %a@." pretty_invariant invariant

end



let run () =
  Circle.compute () ;
  Simple.compute ()
