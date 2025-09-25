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

  type ('n, 'm) m = { data : scalar Parray.t ; rows : 'n nat ; cols : 'm nat }
  type ('n, 'm) matrix = M : ('n succ, 'm succ) m -> ('n succ, 'm succ) matrix
  type 'n vector = ('n, zero succ) matrix



  module Matrix = struct

    let index cols i j = i * Nat.to_int cols + j

    let get (type n m) (i : n finite) (j : m finite) (M m : (n, m) matrix) =
      let i = Finite.to_int i and j = Finite.to_int j in
      Parray.get m.data (index m.cols i j)

    let set (type n m) i j num (M m : (n, m) matrix) : (n, m) matrix =
      let i = Finite.to_int i and j = Finite.to_int j in
      let data = Parray.set m.data (index m.cols i j) num in
      M { m with data }

    let dimensions (type n m) (M m : (n, m) matrix) : n nat * m nat =
      m.rows, m.cols


    type ('n, 'm) formatter = ('n, 'm) matrix Pretty_utils.formatter
    type ('n, 'm) boxing = ('n, 'm) formatter -> ('n, 'm) formatter

    let boxing : type n m. n finite -> n nat -> (n, m) boxing = fun i rows ->
      let i = Finite.to_int i and rows = Nat.to_int rows in
      let pp_vec pp fmt v = Format.fprintf fmt "[%a]" pp v in
      if Stdlib.(i < 0 || rows < 1) then assert false
      else if Stdlib.(i == 0 && rows == 1) then pp_vec
      else if Stdlib.(i == 0) then Unicode.pp_ceil
      else if Stdlib.(i == rows - 1) then Unicode.pp_floor
      else (fun pp fmt v -> Format.fprintf fmt "|%a|" pp v)

    let pp_row_unboxed : type n m. n finite -> (n, m) formatter = fun i fmt (M m) ->
      let scalar fmt j = Field.pretty fmt (get i j (M m)) in
      let spacer fmt j = if j != last m.cols then Format.fprintf fmt " ; " in
      let pp_elt j () = Format.fprintf fmt "%a%a" scalar j spacer j in
      Finite.for_each pp_elt m.cols ()

    let pp_row : type n m. n finite -> (n, m) formatter = fun i fmt (M m) ->
      boxing i m.rows (pp_row_unboxed i) fmt (M m)

    let pretty : type n m. (n, m) formatter = fun fmt (M m) ->
      let cut fmt i = if i != last m.rows then Format.pp_print_cut fmt () in
      let row i () = Format.fprintf fmt "@[<h>%a@]%a" (pp_row i) (M m) cut i in
      Finite.for_each row m.rows ()


    let init n m init =
      let rows = Nat.to_int n and cols = Nat.to_int m in
      let t = Parray.init (rows * cols) (fun _ -> Field.zero) in
      let index i j = index m (Finite.to_int i) (Finite.to_int j) in
      let set i j data = Parray.set data (index i j) (init i j) in
      let data = Finite.(for_each (fun i t -> for_each (set i) m t) n t) in
      M { data ; rows = n ; cols = m }

    let zero n m = init n m (fun _ _ -> Field.zero)
    let id n = Finite.for_each (fun i m -> set i i Field.one m) n (zero n n)

    let transpose : type n m. (n, m) matrix -> (m, n) matrix =
      fun (M m) -> init m.cols m.rows (fun j i -> get i j (M m))

    type ('n, 'm) add = ('n, 'm) matrix -> ('n, 'm) matrix -> ('n, 'm) matrix
    let ( + ) : type n m. (n, m) add = fun (M l) (M r) ->
      let ( + ) i j = Field.(get i j (M l) + get i j (M r)) in
      init l.rows l.cols ( + )

    type ('n, 'm) sub = ('n, 'm) matrix -> ('n, 'm) matrix -> ('n, 'm) matrix
    let ( - ) : type n m. (n, m) sub = fun (M l) (M r) ->
      let ( - ) i j = Field.(get i j (M l) - get i j (M r)) in
      init l.rows l.cols ( - )

    type ('n, 'm, 'p) mul = ('n, 'm) matrix -> ('m, 'p) matrix -> ('n, 'p) matrix
    let ( * ) : type n m p. (n, m, p) mul = fun (M l) (M r) ->
      let n = l.rows and m = l.cols and p = r.cols in
      let folder i k j acc = Field.(get i j (M l) * get j k (M r) + acc) in
      let elt i k = Finite.for_each (folder i k) m Field.zero in
      init n p elt

    let ( ** ) : type n m. scalar -> (n, m) matrix -> (n, m) matrix =
      fun l (M m) -> M { m with data = Parray.map (Field.( * ) l) m.data }

    let abs : type n m. (n, m) matrix -> (n, m) matrix =
      fun (M m) -> M { m with data = Parray.map Field.abs m.data }

    let all_components_lower_than l r =
      let rows, cols = dimensions l in
      let lower i j acc = acc && Field.(get i j l < get i j r) in
      let do_row i = Finite.for_each (lower i) cols in
      Finite.for_each do_row rows true

    let norm_inf : type n m. (n, m) matrix -> scalar = fun (M m) ->
      let sum j i acc = Field.(abs (get i j (M m)) + acc) in
      let col j = Finite.for_each (sum j) m.rows Field.zero in
      let max j res = Field.max res (col j) in
      Finite.for_each max m.cols Field.zero

    let norm_one : type n m. (n, m) matrix -> scalar = fun (M m) ->
      let sum i j acc = Field.(abs (get i j (M m)) + acc) in
      let row i = Finite.for_each (sum i) m.cols Field.zero in
      let max i res = Field.max res (row i) in
      Finite.for_each max m.rows Field.zero


    let swap_rows (M m) r r' =
      let swap c m =
        let elt = get r c m and elt' = get r' c m in
        m |> set r c elt' |> set r' c elt
      in Finite.for_each swap m.cols (M m)

    let argmax (M m) starting_row col =
      let max row argmax_row =
        if not Finite.(row < starting_row) then
          let argmax_value = Field.abs (get argmax_row col (M m)) in
          let row_value = Field.abs (get row col (M m)) in
          if Field.(argmax_value < row_value) then row else argmax_row
        else argmax_row
      in Finite.for_each max m.rows starting_row

    let equal : type n m. (n, m) matrix -> (n, m) matrix -> bool = fun l r ->
      let rows, cols = dimensions l in
      let equal_elt row col eq = eq && Field.(get row col l = get row col r) in
      let equal_row row eq = eq && Finite.for_each (equal_elt row) cols eq in
      Finite.for_each equal_row rows true

    let rec back_propagation (M _ as m) inverse start =
      let size, _ = dimensions m in
      if Finite.(first < start) then
        let propagate r (m, inverse) =
          if Finite.(r < start) then
            let f = Field.(get r start m / get start start m) in
            let compute c m = set r c Field.(get r c m - f * get start c m) m in
            let inverse = Finite.for_each compute size inverse in
            let m = Finite.for_each compute size m in
            (m, inverse)
          else (m, inverse)
        in
        let m, inverse = Finite.for_each propagate size (m, inverse) in
        back_propagation m inverse Finite.(prev start |> weaken)
      else if equal m (id size) then Some inverse else None

    let rec inverse_aux (M _ as m) inverse h k =
      let open Option.Operators in
      let size, _ = dimensions m in
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
        let m = Finite.for_each normalize size m in
        let m = swap_rows m h i_max in
        let inverse = Finite.for_each normalize size inverse in
        let inverse = swap_rows inverse h i_max in
        (* For all rows below pivot, fill with zeros and update remaining
           elements in the row. *)
        let rec below_pivot i (m, inverse) =
          if Finite.(h < i) then
            let f = Field.(get i k m / get h k m) in
            let m = set i k Field.zero m in
            let on_row bypass = remaining_current_row bypass f i in
            let m = Finite.for_each (on_row false) size m in
            let inverse = Finite.for_each (on_row true) size inverse in
            (m, inverse)
          else (m, inverse)
        (* Update remaining elements in the current row. *)
        and remaining_current_row bypass f i j m =
          if Finite.(k < j) || bypass
          then set i j Field.(get i j m - f * get h j m) m
          else m
        in
        let m, inverse = Finite.for_each below_pivot size (m, inverse) in
        let- `Callback = m, inverse in
        let* h = Finite.(next h |> strengthen size) in
        let+ k = Finite.(next k |> strengthen size) in
        inverse_aux m inverse h k

    let inverse : type n. (n, n) matrix -> (n, n) matrix option = fun (M m) ->
      let size, _ = dimensions (M m) in
      let m, inverse = inverse_aux (M m) (id size) Finite.first Finite.first in
      back_propagation m inverse (Finite.last size)

  end



  module Vector = struct

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

    let pretty (type n) fmt (vector : n vector) =
      Matrix.(pretty fmt (transpose vector))

    let set (type n) (i : n finite) scalar (M vec : n vector) : n vector =
      M { vec with data = Parray.set vec.data (Finite.to_int i) scalar }

    let norm (type n) (v : n vector) : scalar =
      let max i r = Field.(max (abs (get i v)) r) in
      Finite.for_each max (size v) Field.zero

    let max (type n) (M l : n vector) (M r : n vector) : n vector =
      init l.rows @@ fun i -> Field.max (get i (M l)) (get i (M r))

    let base (type n) (i : n succ finite) (dimension : n succ nat) =
      zero dimension |> set i Field.one

  end



end
