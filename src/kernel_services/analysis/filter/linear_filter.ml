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



module Make (Field : Field.S) = struct

  module Linear = Linear.Space (Field)
  open Linear
  open Nat



  type ('n, 'm) filter =
    | Filter : ('n succ, 'm succ) data -> ('n succ, 'm succ) filter

  and ('n, 'm) data =
    { state : ('n, 'n) matrix
    ; input : ('n, 'm) matrix
    ; center  : 'n vector
    ; measure : 'm vector
    }



  let create ~state ~input ~center ~measure =
    Filter { state ; input ; center ; measure }

  type ('n, 'm) formatter = Format.formatter -> ('n, 'm) filter -> unit
  let pretty : type n m. (n, m) formatter = fun fmt (Filter f) ->
    Format.fprintf fmt "@[<v>" ;
    Format.fprintf fmt "Filter:@ @ " ;
    Format.fprintf fmt "- State :@ @   @[<v>%a@]@ @ " Matrix.pretty f.state ;
    Format.fprintf fmt "- Input :@ @   @[<v>%a@]@ @ " Matrix.pretty f.input ;
    Format.fprintf fmt "@]"



  type 'n invariant = ('n, zero succ succ) matrix

  let invariant rows =
    Matrix.zero rows Nat.(zero |> succ |> succ)

  let lower i invariant =
    Matrix.get i Finite.first invariant

  let upper i invariant =
    Matrix.get i Finite.(next first) invariant

  let bounds i invariant =
    (lower i invariant, upper i invariant)

  let set_lower i bound invariant =
    Matrix.set i Finite.first bound invariant

  let set_upper i bound invariant =
    Matrix.set i Finite.(next first)  bound invariant



  let memoized_powers m =
    let cache = Datatype.Int.Hashtbl.create 17 in
    let find i = Datatype.Int.Hashtbl.find cache i in
    let save i v = Datatype.Int.Hashtbl.add cache i v ; v in
    fun i -> try find i with Not_found -> save i (Matrix.power m i)

  let check_convergence matrix =
    let norm = Matrix.norm matrix in
    if Field.(norm < one) then Some norm else None

  type ('n, 'm) compute = ('n, 'm) filter -> int -> 'n invariant option
  let invariant : type n m. (n, m) compute = fun (Filter f) e ->
    let open Option.Operators in
    let measure = Vector.norm f.measure in
    let powers = memoized_powers f.state in
    let order, _ = Matrix.dimensions f.input in
    let base i = Vector.base i order |> Matrix.transpose in
    let* StrictlyPositive exponent = Nat.of_strictly_positive_int e in
    let+ spectral = powers (Nat.to_int exponent) |> check_convergence in
    (* Computation of the inputs contribution for the i-th state dimension *)
    let input base e = Matrix.(base * powers e * f.input |> norm) in
    let add_input base e res = Field.(res + input base (Finite.to_int e)) in
    let input i = Finite.for_each (base i |> add_input) exponent Field.zero in
    (* Computation of the center contribution for the i-th state dimension *)
    let center e = Matrix.(powers e * f.center) in
    let add_center e res = Matrix.(res + center (Finite.to_int e)) in
    let center = Finite.for_each add_center exponent (Vector.zero order) in
    let center i = Matrix.(base i * center |> norm) in
    (* Bounds computation for each state dimension *)
    let numerator sign i = Field.(center i + sign * measure * input i) in
    let bound sign i = Field.(numerator sign i / (one - spectral)) in
    let lower i inv = set_lower i (bound Field.(neg one) i) inv in
    let upper i inv = set_upper i (bound Field.one i) inv in
    Finite.(invariant order |> for_each lower order |> for_each upper order)

  (* - Powers : k * n^3
     - Input i : n x n mul + n x m mul + norm
        -> n^2 + nm + 1 because of projection
     - Center i : n x n mul + k * n x n add + n x n mul + norm
        -> n^2 + kn^2 + n^2 + 1 because of projection
     - Dimension i : O(kn^2 + nm)
     Total : O(kn^3 + mn^2)
   *)
end
