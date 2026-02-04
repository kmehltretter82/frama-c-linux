(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Nat
open Finite



module Space (Field : Field.S) = struct

  type scalar = Field.scalar

  type ('n, 'm) matrix = { data : scalar Parray.t ; rows : 'n nat ; cols : 'm nat }
  type 'n vector = ('n, zero succ) matrix



  module Matrix = struct

    let index cols i j = i * Nat.to_int cols + j

    let get (type n m) (i : n finite) (j : m finite) (m : (n, m) matrix) =
      let i = Finite.to_int i and j = Finite.to_int j in
      Parray.get m.data (index m.cols i j)

    let set (type n m) i j num (m : (n, m) matrix) : (n, m) matrix =
      let i = Finite.to_int i and j = Finite.to_int j in
      { m with data = Parray.set m.data (index m.cols i j) num }

    let dimensions m = m.rows, m.cols


    type ('n, 'm) formatter = ('n, 'm) matrix Pretty_utils.formatter
    type ('n, 'm) boxing = ('n, 'm) formatter -> ('n, 'm) formatter

    let boxing : type n m. n finite -> n nat -> (n, m) boxing = fun i rows ->
      let i = Finite.to_int i and rows = Nat.to_int rows in
      let pp_vec pp fmt v = Format.fprintf fmt "[%a]" pp v in
      if Stdlib.(i == 0 && rows == 1) then pp_vec
      else if Stdlib.(i == 0) then Unicode.pp_ceil
      else if Stdlib.(i == rows - 1) then Unicode.pp_floor
      else (fun pp fmt v -> Format.fprintf fmt "|%a|" pp v)

    let pp_row_unboxed i fmt m =
      let scalar fmt j = Field.pretty fmt (get i j m) in
      let spacer fmt j = if j != last m.cols then Format.fprintf fmt " ; " in
      let pp_elt j = Format.fprintf fmt "%a%a" scalar j spacer j in
      Finite.iter pp_elt m.cols

    let pretty fmt m =
      let cut fmt i = if i != last m.rows then Format.pp_print_cut fmt () in
      let pp_row i fmt m = boxing i m.rows (pp_row_unboxed i) fmt m in
      let row i = Format.fprintf fmt "@[<h>%a@]%a" (pp_row i) m cut i in
      Finite.iter row m.rows


    let init n m init =
      let rows = Nat.to_int n and cols = Nat.to_int m in
      let t = Parray.init (rows * cols) (fun _ -> Field.zero) in
      let index i j = index m (Finite.to_int i) (Finite.to_int j) in
      let set i j data = Parray.set data (index i j) (init i j) in
      let data = Finite.(fold (fun i t -> fold (set i) m t) n t) in
      { data ; rows = n ; cols = m }

    let zero n m = init n m (fun _ _ -> Field.zero)
    let id n = Finite.fold (fun i m -> set i i Field.one m) n (zero n n)

    let of_array n m rows = init n m @@ fun i j ->
      Field.of_string rows.(Finite.to_int i).(Finite.to_int j)

    let transpose m = init m.cols m.rows (fun j i -> get i j m)

    let abs m = { m with data = Parray.map Field.abs m.data }
    let scale k m = { m with data = Parray.map (Field.( * ) k) m.data }
    let ( + ) l r = init l.rows l.cols Field.(fun i j -> get i j l + get i j r)
    let ( - ) l r = init l.rows l.cols Field.(fun i j -> get i j l - get i j r)
    let ( / ) l r = init l.rows l.cols Field.(fun i j -> get i j l / get i j r)

    let ( * ) l r =
      let n = l.rows and m = l.cols and p = r.cols in
      let folder i k j acc = Field.(get i j l * get j k r + acc) in
      let elt i k = Finite.fold (folder i k) m Field.zero in
      init n p elt

    let all_components_lower_than l r =
      let lower i j acc = acc && Field.(get i j l < get i j r) in
      let do_row i = Finite.fold (lower i) l.cols in
      Finite.fold do_row l.rows true

    let norm_inf m =
      let sum j i acc = Field.(abs (get i j m) + acc) in
      let col j = Finite.fold (sum j) m.rows Field.zero in
      let max j res = Field.max res (col j) in
      Finite.fold max m.cols Field.zero

    let norm_one m =
      let sum i j acc = Field.(abs (get i j m) + acc) in
      let row i = Finite.fold (sum i) m.cols Field.zero in
      let max i res = Field.max res (row i) in
      Finite.fold max m.rows Field.zero


    let swap_rows m r r' =
      let swap c m =
        let elt = get r c m and elt' = get r' c m in
        m |> set r c elt' |> set r' c elt
      in Finite.fold swap m.cols m

    let argmax m starting_row col =
      let max row argmax_row =
        if not Finite.(row < starting_row) then
          let argmax_value = Field.abs (get argmax_row col m) in
          let row_value = Field.abs (get row col m) in
          if Field.(argmax_value < row_value) then row else argmax_row
        else argmax_row
      in Finite.fold max m.rows starting_row

    let equal l r =
      let equal_elt row col = Field.(get row col l = get row col r) in
      let equal_row row = Finite.forall (equal_elt row) l.cols in
      Finite.forall equal_row l.rows

    let rec back_propagation m inverse start =
      let size = m.rows in
      if Finite.(first < start) then
        let propagate r (m, inverse) =
          if Finite.(r < start) then
            let f = Field.(get r start m / get start start m) in
            let compute c m = set r c Field.(get r c m - f * get start c m) m in
            let inverse = Finite.fold compute size inverse in
            let m = Finite.fold compute size m in
            (m, inverse)
          else (m, inverse)
        in
        let m, inverse = Finite.fold propagate size (m, inverse) in
        back_propagation m inverse Finite.(prev start |> weaken)
      else if equal m (id size) then Some inverse else None

    let rec inverse_aux m inverse h k =
      let open Option.Operators in
      let size = m.rows in
      (* Monadic operator to return [Option.value ~default] on the result of f *)
      let ( let- ) default f = Option.(f `Callback |> value ~default) in
      (* Find the k-th pivot *)
      let i_max = argmax m h k in
      if Field.(get i_max k m = zero) then
        (* No pivot here, goes to the next. Stop if we've done them all. *)
        let- `Callback = m, inverse in
        let+ k = Finite.(next k |> strengthen size) in
        inverse_aux m inverse h k
      else
        let value = get i_max k m in
        let divide col m = Field.(get i_max col m / value) in
        let normalize col m = set i_max col (divide col m) m in
        let m = Finite.fold normalize size m in
        let m = swap_rows m h i_max in
        let inverse = Finite.fold normalize size inverse in
        let inverse = swap_rows inverse h i_max in
        (* For all rows below pivot, fill with zeros and update remaining
           elements in the row. *)
        let rec below_pivot i (m, inverse) =
          if Finite.(h < i) then
            let f = Field.(get i k m / get h k m) in
            let m = set i k Field.zero m in
            let on_row bypass = remaining_current_row bypass f i in
            let m = Finite.fold (on_row false) size m in
            let inverse = Finite.fold (on_row true) size inverse in
            (m, inverse)
          else (m, inverse)
        (* Update remaining elements in the current row. *)
        and remaining_current_row bypass f i j m =
          if Finite.(k < j) || bypass
          then set i j Field.(get i j m - f * get h j m) m
          else m
        in
        let m, inverse = Finite.fold below_pivot size (m, inverse) in
        let- `Callback = m, inverse in
        let* h = Finite.(next h |> strengthen size) in
        let+ k = Finite.(next k |> strengthen size) in
        inverse_aux m inverse h k

    let inverse m =
      let size = m.rows in
      let m, inverse = inverse_aux m (id size) Finite.first Finite.first in
      back_propagation m inverse (Finite.last size)

  end



  module Vector = struct

    let init size f =
      let data = Parray.init (Nat.to_int size) (fun _ -> Field.zero) in
      let set i data = Parray.set data (Finite.to_int i) (f i) in
      let data = Finite.fold set size data in
      { data ; rows = size ; cols = Nat.one }

    let of_array size t =
      init size (fun i -> Field.of_string t.(Finite.to_int i))

    let size (type n) (vector : n vector) : n nat = vector.rows
    let repeat n size = init size (fun _ -> n)
    let zero size = repeat Field.zero size

    let get (type n) (i : n finite) (vec : n vector) : scalar =
      Parray.get vec.data (Finite.to_int i)

    let pretty (type n) fmt (vector : n succ vector) =
      Matrix.(pretty fmt (transpose vector))

    let set (type n) (i : n finite) scalar (vec : n vector) : n vector =
      { vec with data = Parray.set vec.data (Finite.to_int i) scalar }

    let norm (type n) (v : n vector) : scalar =
      let max i r = Field.(max (abs (get i v)) r) in
      Finite.fold max (size v) Field.zero

    let max (type n) (l : n vector) (r : n vector) : n vector =
      init l.rows @@ fun i -> Field.max (get i l) (get i r)

    let base (type n) (i : n succ finite) (dimension : n succ nat) =
      zero dimension |> set i Field.one

  end



end
