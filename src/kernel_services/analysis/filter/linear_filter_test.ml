(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

module Filter = Linear_filter.Make (Rational)
module Linear = Filter.Linear
module Matrix = Linear.Matrix
module Vector = Linear.Vector

let fin size n = Finite.of_int size n |> Option.get
let set row col i j n = Linear.Matrix.set (fin row i) (fin col j) n

let pretty_limit invariant fmt i =
  let permanent = invariant.Filter.permanent in
  let lower = Vector.get i permanent.Field.lower in
  let upper = Vector.get i permanent.Field.upper in
  Format.fprintf fmt "@[<h>[%a .. %a]@]"
    Rational.pretty lower
    Rational.pretty upper

let pretty_invariant order fmt = function
  | None -> Unicode.pp_top fmt
  | Some invariant ->
    let pp f i = pretty_limit invariant f i in
    let pp f i = Format.fprintf f "@[<h>* %d : %a@]@," (Finite.to_int i) pp i in
    let pretty fmt () = Finite.for_each (fun i () -> pp fmt i) order () in
    let transition = List.length invariant.transition in
    Format.fprintf fmt "@[<v>" ;
    Format.fprintf fmt "Transition duration : %d iterations@ " transition ;
    Format.fprintf fmt "State space invariant :@ %a@]" pretty ()



(* Invariant computation for the filter:
     X = 0.68 * X - 0.68 * Y + E1;
     Y = 0.68 * X + 0.68 * Y + E2;
   with E1 ∈ [-1 .. 1] and E2 ∈ [-1 .. 1]. *)
module Circle = struct

  let order = Nat.(succ one)
  let delay = Nat.(succ one)

  let initial =
    Vector.zero order
    |> set order Nat.one 0 0 Rational.(of_int 1000)
    |> set order Nat.one 1 0 Rational.(of_int  200)

  let shift =
    Vector.zero order

  let measure_center =
    Vector.zero delay

  let measure_radius =
    Vector.repeat Q.one delay

  let measure_matrix =
    Matrix.zero order delay
    |> set order delay 0 0 Q.one
    |> set order delay 1 1 Q.one

  let state_matrix =
    Matrix.zero order order
    |> set order order 0 0 Rational.(of_float 0.68)
    |> set order order 0 1 Rational.(of_float ~-.0.68)
    |> set order order 1 0 Rational.(of_float 0.68)
    |> set order order 1 1 Rational.(of_float 0.68)

  let filter =
    Filter.create
      ~initial
      ~shift
      ~measure_center
      ~measure_radius
      ~measure_matrix
      ~state_matrix

  let compute () =
    let invariant = Filter.behavior filter in
    Kernel.result "@[<v>Circle :@,%a@,@]" (pretty_invariant order) invariant

end



(* Invariant computation for the filter:
     X = 1.5 * X - 0.7 * Y + E + 1;
     Y = X + 1;
   with E ∈ [-0.1 .. 0.1]. *)
module Simple = struct

  let order = Nat.(succ one)
  let delay = Nat.one

  let initial =
    Vector.zero order

  let shift =
    Vector.repeat Q.one order

  let measure_center =
    Vector.zero delay

  let measure_radius =
    Vector.repeat (Rational.of_float 0.1) delay

  let measure_matrix =
    Matrix.zero order delay
    |> set order delay 0 0 Rational.one
    |> set order delay 1 0 Rational.zero

  let state_matrix =
    Matrix.zero order order
    |> set order order 0 0 Rational.(of_float 1.5)
    |> set order order 0 1 Rational.(of_float ~-.0.7)
    |> set order order 1 0 Rational.(of_float 1.)
    |> set order order 1 1 Rational.(of_float 0.)

  let filter =
    Filter.create
      ~initial
      ~shift
      ~measure_center
      ~measure_radius
      ~measure_matrix
      ~state_matrix

  let compute () =
    let invariant = Filter.behavior filter in
    Kernel.result "@[<v>Simple :@,%a@,@]" (pretty_invariant order) invariant

end



let run () =
  Circle.compute () ;
  Simple.compute ()
