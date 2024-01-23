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
  open Field.Types
  open Linear



  let rec first_steps max steps matrix exponent =
    let steps = (matrix, exponent) :: steps in
    if Field.(Matrix.norm matrix < one) then
      if exponent * 2 > max then Some steps
      else first_steps max steps Matrix.(matrix * matrix) (exponent * 2)
    else if exponent <= max then
      first_steps max steps Matrix.(matrix * matrix) (exponent * 2)
    else None

  let rec refine max = function
    | [] -> None
    | [ (matrix, exponent) ] -> Some (Matrix.norm matrix, exponent)
    | (matrix, exponent) :: (matrix', exponent') :: previous ->
      let exponent'' = exponent + exponent' in
      if exponent'' > max
      then refine max ((matrix, exponent) :: previous)
      else refine max ((Matrix.(matrix * matrix'), exponent'') :: previous)

  let find_exponent max_acceptable_exponent base =
    let open Option.Operators in
    let* steps = first_steps max_acceptable_exponent [] base 1 in
    refine max_acceptable_exponent steps



  module Types = struct

    type ('n, 'm) filter =
      | Filter : ('n succ, 'm succ) data -> ('n succ, 'm succ) filter

    and ('n, 'm) data =
      { state : ('n, 'n) matrix
      ; input : ('n, 'm) matrix
      ; measure : 'm vector
      }

  end

  open Types



  let create state input measure = Filter { state ; input ; measure }

  type ('n, 'm) formatter = Format.formatter -> ('n, 'm) filter -> unit
  let pretty : type n m. (n, m) formatter = fun fmt (Filter f) ->
    Format.fprintf fmt "Filter:@.@." ;
    Format.fprintf fmt "- State :@.@.  @[<v>%a@]@.@." Matrix.pretty f.state ;
    Format.fprintf fmt "- Input :@.@.  @[<v>%a@]@.@." Matrix.pretty f.input

  let sum order p norm stop =
    let ( + ) res acc = Field.(res + norm acc) in
    let rec aux (m, r) i = if i >= 0 then aux (p m, r + m) (i - 1) else r in
    aux (Matrix.id order, Field.zero) (stop - 1)

  type ('n, 'm) invariant = ('n, 'm) filter -> int -> scalar option
  let invariant : type n m. (n, m) invariant = fun (Filter f) max ->
    let open Option.Operators in
    let order, _ = Matrix.dimensions f.input in
    let+ spectral, exponant = find_exponent max f.state in
    let power p = Matrix.(f.state * p) in
    let norm  p = Matrix.(p * f.input |> norm) in
    let sum = sum order power norm exponant in
    let bound = Field.(Vector.norm f.measure * sum / (one - spectral)) in
    let order = Field.of_int (Nat.to_int order) in
    Field.(bound / order)

end
