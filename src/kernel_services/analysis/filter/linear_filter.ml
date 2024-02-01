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

open Nat



module Make (Field : Field.S) = struct

  module Linear = Linear.Space (Field)
  open Linear



  let rec first_steps target steps matrix exponent =
    let steps' = (matrix, exponent) :: steps in
    if exponent * 2 > target
    then if exponent <= target then steps' else steps
    else first_steps target steps' Matrix.(matrix * matrix) (exponent * 2)

  let rec refine target = function
    | [] -> None
    | [ (matrix, _) ] ->
      let norm = Matrix.norm matrix in
      if Field.(norm < one) then Some norm else None
    | (matrix, exponent) :: (matrix', exponent') :: previous ->
      let exponent'' = exponent + exponent' in
      if exponent'' > target
      then refine target ((matrix, exponent) :: previous)
      else refine target ((Matrix.(matrix * matrix'), exponent'') :: previous)

  let find_spectral_radius target base =
    first_steps target [] base 1 |> refine target



  type ('n, 'm) filter =
    | Filter : ('n succ, 'm succ) data -> ('n succ, 'm succ) filter

  and ('n, 'm) data =
    { state : ('n, 'n) matrix
    ; input : ('n, 'm) matrix
    ; measure : 'm vector
    }



  let create state input measure = Filter { state ; input ; measure }

  type ('n, 'm) formatter = Format.formatter -> ('n, 'm) filter -> unit
  let pretty : type n m. (n, m) formatter = fun fmt (Filter f) ->
    Format.fprintf fmt "@[<v>" ;
    Format.fprintf fmt "Filter:@ @ " ;
    Format.fprintf fmt "- State :@ @   @[<v>%a@]@ @ " Matrix.pretty f.state ;
    Format.fprintf fmt "- Input :@ @   @[<v>%a@]@ @ " Matrix.pretty f.input ;
    Format.fprintf fmt "@]"

  let sum order p norm stop =
    let ( + ) res acc = Field.(res + norm acc) in
    let rec aux (m, r) i = if i >= 0 then aux (p m, r + m) (i - 1) else r in
    aux (Matrix.id order, Field.zero) (stop - 1)

  type ('n, 'm) invariant = ('n, 'm) filter -> int -> Field.scalar option
  let invariant : type n m. (n, m) invariant = fun (Filter f) exponent ->
    let open Option.Operators in
    let order, _ = Matrix.dimensions f.input in
    let+ spectral = find_spectral_radius exponent f.state in
    let power p = Matrix.(f.state * p) in
    let norm  p = Matrix.(p * f.input |> norm) in
    let sum = sum order power norm exponent in
    let bound = Field.(Vector.norm f.measure * sum / (one - spectral)) in
    let order = Field.of_int (Nat.to_int order) in
    Field.(bound / order)

end
