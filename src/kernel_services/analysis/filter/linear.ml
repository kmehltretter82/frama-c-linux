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
open Finite



module Space (Field : Field.S) = struct

  type scalar = Field.scalar

  type ('n, 'm) m = { data : scalar Parray.t ; rows : 'n nat ; cols : 'm nat }
  type ('n, 'm) matrix = M : ('n succ, 'm succ) m -> ('n succ, 'm succ) matrix
  type 'n vector = ('n, zero succ) matrix



  module Vector = struct

    let pretty (type n) fmt (M { data ; _ } : n vector) =
      Parray.pretty ~sep:"@ " Field.pretty fmt data

    let init size f =
      let data = Parray.init (Nat.to_int size) (fun _ -> Field.zero) in
      let set i data = Parray.set data (Finite.to_int i) (f i) in
      let data = Finite.for_each set size data in
      M { data ; rows = size ; cols = Nat.one }

    let size (type n) (M vector : n vector) : n nat = vector.rows
    let repeat n size = init size (fun _ -> n)
    let zero size = repeat Field.zero size

    let get (type n) (i : n finite) (M vec : n vector) : scalar =
      Parray.get vec.data (Finite.to_int i)

    let set (type n) (i : n finite) scalar (M vec : n vector) : n vector =
      M { vec with data = Parray.set vec.data (Finite.to_int i) scalar }

    let norm (type n) (M vector : n vector) =
      Parray.fold (fun _ a acc -> Field.(abs a + acc)) vector.data Field.zero

    let ( * ) (type n) (l : n vector) (r : n vector) =
      let inner i acc = Field.(acc + get i l * get i r) in
      Finite.for_each inner (size l) Field.zero

  end



  module Matrix = struct

    let index cols i j = i * Nat.to_int cols + j

    let get (type n m) (i : n finite) (j : m finite) (M m : (n, m) matrix) =
      let i = Finite.to_int i and j = Finite.to_int j in
      Parray.get m.data (index m.cols i j)

    let set (type n m) i j num (M m : (n, m) matrix) : (n, m) matrix =
      let i = Finite.to_int i and j = Finite.to_int j in
      let data = Parray.set m.data (index m.cols i j) num in
      M { m with data }

    let row row (M m) = Vector.init m.cols @@ fun i -> get row i (M m)
    let col col (M m) = Vector.init m.rows @@ fun i -> get i col (M m)

    let dimensions : type n m. (n, m) matrix -> n nat * m nat =
      fun (M m) -> m.rows, m.cols

    let pretty (type n m) fmt (M m : (n, m) matrix) =
      let cut i = if not Finite.(i == first) then Format.pp_print_cut fmt () in
      let row i = Format.fprintf fmt "@[<h>%a@]" Vector.pretty (row i (M m)) in
      let pretty () = Finite.for_each (fun i () -> cut i ; row i) m.rows () in
      Format.pp_open_vbox fmt 0 ; pretty () ; Format.pp_close_box fmt ()

    let init n m init =
      let rows = Nat.to_int n and cols = Nat.to_int m in
      let t = Parray.init (rows * cols) (fun _ -> Field.zero) in
      let index i j = index m (Finite.to_int i) (Finite.to_int j) in
      let set i j data = Parray.set data (index i j) (init i j) in
      let data = Finite.(for_each (fun i t -> for_each (set i) m t) n t) in
      M { data ; rows = n ; cols = m }

    let zero n m = init n m (fun _ _ -> Field.zero)
    let id n = Finite.for_each (fun i m -> set i i Field.one m) n (zero n n)

    type ('n, 'm) add = ('n, 'm) matrix -> ('n, 'm) matrix -> ('n, 'm) matrix
    let ( + ) : type n m. (n, m) add = fun (M l) (M r) ->
      let ( + ) i j = Field.(get i j (M l) + get i j (M r)) in
      init l.rows l.cols ( + )

    type ('n, 'm, 'p) mul = ('n, 'm) matrix -> ('m, 'p) matrix -> ('n, 'p) matrix
    let ( * ) : type n m p. (n, m, p) mul = fun (M l) (M r) ->
      let ( * ) i j = Vector.(row i (M l) * col j (M r)) in
      init l.rows r.cols ( * )

    let norm : type n m. (n, m) matrix -> scalar = fun (M m) ->
      let max i res = Field.max res (col i (M m) |> Vector.norm) in
      Finite.for_each max m.cols Field.zero

  end

end
