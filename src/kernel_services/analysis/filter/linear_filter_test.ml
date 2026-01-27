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



let set row col i j n =
  let fin size n = Finite.of_int size n |> Option.get in
  Linear.Matrix.set (fin row i) (fin col j) (Rational.of_string n)

let pretty_ball fmt ball =
  let Filter.Ball.{ center ; radius } = ball in
  let n = Vector.size center in
  let pretty i () =
    let c, r = Vector.(get i center, get i radius) in
    let l, r = Rational.(c - r, c + r) in
    Format.fprintf fmt "* %d : [%a .. %a]@ "
      (Finite.to_int i)
      Rational.pretty l
      Rational.pretty r
  in Finite.for_each pretty n ()

let pretty_behavior fmt = function
  | None -> Unicode.pp_top fmt
  | Some Filter.{ transition ; permanent } ->
    Format.fprintf fmt "@[<v>" ;
    Format.fprintf fmt "Transition duration : %d iterations@ "
      (List.length transition) ;
    Format.fprintf fmt "State space invariant :@ %a"
      pretty_ball permanent ;
    Format.fprintf fmt "@]"



(* Invariant computation for the filter:
     X = 0.68 * X - 0.68 * Y + E1;
     Y = 0.68 * X + 0.68 * Y + E2;
   with E1 ∈ [-1 .. 1] and E2 ∈ [-1 .. 1]. *)
module Circle = struct

  let n = Nat.(succ one)

  let state_matrix =
    Matrix.zero n n
    |> set n n 0 0 "+0.68"
    |> set n n 0 1 "-0.68"
    |> set n n 1 0 "+0.68"
    |> set n n 1 1 "+0.68"

  let input_matrix =
    Matrix.zero n n
    |> set n n 0 0 "1"
    |> set n n 1 1 "1"

  let input_space =
    let center = Vector.zero n in
    let radius = Vector.repeat Q.one n in
    Filter.Ball.make center radius

  let initial_state =
    Vector.zero n
    |> set n Nat.one 0 0 "1000"
    |> set n Nat.one 1 0 "200"

  let shift =
    Vector.zero n

  let system =
    Filter.{ state_matrix ; input_matrix ; input_space ; initial_state ; shift }

  let compute () =
    let behavior = Filter.behavior ~completion_target:99.0 system in
    Kernel.result "@[<v>Circle :@,%a@,@]" pretty_behavior behavior

end



(* Invariant computation for the filter:
     X = 1.5 * X - 0.7 * Y + E + 1;
     Y = X + 1;
   with E ∈ [-0.1 .. 0.1]. *)
module Simple = struct

  let order = Nat.(succ one)
  let delay = Nat.one

  let state_matrix =
    Matrix.zero order order
    |> set order order 0 0 "+1.5"
    |> set order order 0 1 "-0.7"
    |> set order order 1 0 "+1.0"
    |> set order order 1 1 "+0.0"

  let input_matrix =
    Matrix.zero order delay
    |> set order delay 0 0 "1"
    |> set order delay 1 0 "0"

  let input_space =
    let center = Vector.zero delay in
    let radius = Vector.repeat (Rational.of_string "0.1") delay in
    Filter.Ball.make center radius

  let initial_state =
    Vector.zero order

  let shift =
    Vector.repeat Q.one order

  let system =
    Filter.{ state_matrix ; input_matrix ; input_space ; initial_state ; shift }

  let compute () =
    let behavior = Filter.behavior ~completion_target:99.0 system in
    Kernel.result "@[<v>Simple :@,%a@,@]" pretty_behavior behavior

end



module Three_dimensions = struct

  let n = Nat.(succ (succ one))

  let state_matrix =
    Matrix.zero n n
    |> set n n 0 0 "+1.20"
    |> set n n 0 1 "-0.20"
    |> set n n 0 2 "-0.30"
    |> set n n 1 0 "+0.70"
    |> set n n 1 1 "-0.30"
    |> set n n 1 2 "+0.60"
    |> set n n 2 0 "-0.07"
    |> set n n 2 1 "+0.91"
    |> set n n 2 2 "-0.12"

  let input_matrix =
    Matrix.zero n n
    |> set n n 0 0 "+1.00"
    |> set n n 0 1 "+0.00"
    |> set n n 0 2 "+0.50"
    |> set n n 1 0 "+0.00"
    |> set n n 1 1 "+1.00"
    |> set n n 1 2 "-0.50"
    |> set n n 2 0 "+0.30"
    |> set n n 2 1 "+0.20"
    |> set n n 2 2 "+0.00"

  let input_center =
    Vector.zero n
    |> set n Nat.one 0 0 "+100"
    |> set n Nat.one 1 0 "-100"
    |> set n Nat.one 2 0 "+200"

  let input_radius =
    Vector.zero n
    |> set n Nat.one 0 0 "+1"
    |> set n Nat.one 1 0 "+1"
    |> set n Nat.one 2 0 "+1"

  let input_space =
    Filter.Ball.make input_center input_radius

  let initial_state =
    Vector.zero n
    |> set n Nat.one 0 0 "1000"
    |> set n Nat.one 1 0 "1000"
    |> set n Nat.one 2 0 "2000"

  let shift =
    Vector.zero n

  let system =
    Filter.{ state_matrix ; input_matrix ; input_space ; initial_state ; shift }

  let compute () =
    let behavior = Filter.behavior ~completion_target:80.0 system in
    Kernel.result "@[<v>3D :@,%a@,@]" pretty_behavior behavior

end



let run () =
  Circle.compute () ;
  Simple.compute () ;
  Three_dimensions.compute ()
