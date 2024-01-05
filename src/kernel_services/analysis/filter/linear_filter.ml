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

open Nat.Types



module Make (Field : Field.S) = struct

  module Linear = Linear.Space (Field)
  open Linear.Types


  (* Invariant search fuel parameters. TODO: let the user change those. *)
  let fuel = 50
  let coarse_refinement_fuel = 5
  let fine_refinement_fuel = 50
  let refinement_threshold = 200

  (* Find a first exponant such as the spectral radius is lower than one. *)
  let rec first_exponant m exp fuel =
    if Field.(Linear.Matrix.norm m <= one) then (exp, m)
    else if fuel < 0 then raise (Invalid_argument "Divergeant filter")
    else first_exponant Linear.Matrix.(m * m) (exp * 2) (fuel - 1)

  (* Refine the exponant to improve the precision. *)
  let rec refine base m exp coarse fine =
    if coarse < 0 || fine < 0 || exp > refinement_threshold
    then exp, m
    else if (exp * 2) > refinement_threshold
    then refine base Linear.Matrix.(base * m) (exp + 1) coarse (fine - 1)
    else refine base Linear.Matrix.(m * m) (exp * 2) (coarse - 1) fine

  (* Looking for an exponant n such as norm(A^n) ≤ 1, which implies that the
     spectral radius of A is lower than 1. The exponant is refined to improve the
     invariant's precision. *)
  let find_exponant base =
    let exponant, matrix = first_exponant base 1 fuel in
    let coarse = coarse_refinement_fuel and fine = fine_refinement_fuel in
    let exponant, matrix = refine base matrix exponant coarse fine in
    (Linear.Matrix.norm matrix, exponant)



  module Types = struct
    type ('n, 'm) filter = Filter : ('n succ, 'm succ) data -> ('n, 'm) filter
    and ('n, 'm) data =
      { state : ('n, 'n) matrix
      ; input : ('n, 'm) matrix
      ; measure : 'm vector
      }
  end

  open Types



  let create state input measure = Filter { state ; input ; measure }

  let pretty fmt (Filter f) =
    let open Linear in
    Format.fprintf fmt "Filter:@.@." ;
    Format.fprintf fmt "- State :@.@.  @[<v>%a@]@.@." Matrix.pretty f.state ;
    Format.fprintf fmt "- Input :@.@.  @[<v>%a@]@.@." Matrix.pretty f.input

  let sum order f g stop =
    let rec compute (acc, res) i =
      if i > 0 then compute (f acc, Field.(res + g acc)) (i - 1) else res
    in compute (Linear.Matrix.id order, Field.zero) (stop - 1)

  let invariant (Filter f) =
    let order, _ = Linear.Matrix.dimensions f.input in
    let spectral, exponant = find_exponant f.state in
    let power p = Linear.Matrix.(f.state * p) in
    let norm  p = Linear.Matrix.(p * f.input |> norm) in
    let sum = sum order power norm exponant in
    let bound = Field.(Linear.Vector.norm f.measure * sum / (one - spectral)) in
    let order = Field.of_int (Nat.to_int order) in
    Field.(bound / order)

end
