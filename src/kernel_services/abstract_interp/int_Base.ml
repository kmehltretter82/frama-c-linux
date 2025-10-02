(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Abstract_interp

type i = Top | Value of Z.t

let equal i1 i2 = match i1, i2 with
  | Top, Top -> true
  | Value i1, Value i2 -> Z.equal i1 i2
  | Top, Value _ | Value _, Top -> false

let compare i1 i2 = match i1, i2 with
  | Top, Top -> 0
  | Value i1, Value i2 -> Z.compare i1 i2
  | Top, Value _ -> -1
  | Value _, Top -> 1

let hash = function
  | Top -> 37
  | Value i -> Z.hash i

let pretty fmt = function
  | Top -> Format.fprintf fmt "Top"
  | Value i -> Format.fprintf fmt "<%a>" Int.pretty i

include Datatype.Make
    (struct
      type t = i (*= Top | Value of Z.t *)
      let name = "Int_Base.t"
      let structural_descr =
        Structural_descr.t_sum [| [| Datatype.Integer.packed_descr |] |]
      let reprs = Top :: List.map (fun v -> Value v) Datatype.Integer.reprs
      let equal = equal
      let compare = compare
      let hash = hash
      let rehash = Datatype.identity
      let copy = Fun.id
      let pretty = pretty
      let mem_project = Datatype.never_any_project
    end)

let minus_one = Value Int.minus_one
let one = Value Int.one
let zero = Value Int.zero
let is_zero x = equal x zero
let top = Top
let is_top v = (v = Top)
let neg x =
  match x with
  | Value v -> Value (Int.neg v)
  | Top -> x
let inject i = Value i

let project = function
  | Top -> raise Error_Top
  | Value i -> i

let cardinal_zero_or_one = function
  | Top -> false
  | Value _ -> true
