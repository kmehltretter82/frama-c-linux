(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2019                                               *)
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

open Abstract_interp

(* Make sure all this is synchronized with the default value of -ilevel *)
let small_cardinal = ref 8
let small_cardinal_Int = ref (Int.of_int !small_cardinal)
let small_cardinal_log = ref 3

let set_small_cardinal i =
  assert (2 <= i && i <= 1024);
  let rec log j p =
    if i <= p then j
    else log (j+1) (2*p)
  in
  small_cardinal := i;
  small_cardinal_Int := Int.of_int i;
  small_cardinal_log := log 1 2;
  (* TODO: share this code with Int_set *)
  Int_set.set_small_cardinal i

let get_small_cardinal () = !small_cardinal

let emitter = Lattice_messages.register "Ival"
let log_imprecision s = Lattice_messages.emit_imprecision emitter s

module Widen_Arithmetic_Value_Set = struct
  include Datatype.Integer.Set

  let default_widen_hints =
    of_list (List.map Int.of_int [-1;0;1])
end

module O = FCSet.Make(Integer)

type t =
  | Set of Int_set.t
  | Float of Fval.t
  | Itv of Int_interval.t
  (* Binary abstract operations do not model precisely float/integer operations.
     It is the responsibility of the callers to have two operands of the same
     implicit type. The only exception is for [singleton_zero], which is the
     correct representation of [0.] *)


module Widen_Hints = Widen_Arithmetic_Value_Set
type size_widen_hint = Integer.t
type numerical_widen_hint = Widen_Hints.t * Fc_float.Widen_Hints.t
type widen_hint = size_widen_hint * numerical_widen_hint

let bottom = Set Int_set.bottom
let top = Itv Int_interval.top

let hash = function
  | Set s -> Int_set.hash s
  | Itv i -> Int_interval.hash i
  | Float f -> 3 + 17 * Fval.hash f

let compare e1 e2 =
  if e1==e2 then 0 else
    match e1, e2 with
    | Set s1, Set s2 -> Int_set.compare s1 s2
    | Itv i1, Itv i2 -> Int_interval.compare i1 i2
    | Float f1, Float f2 -> Fval.compare f1 f2
    | _, Set _ -> 1
    | Set _, _ -> -1
    | _, Itv _ -> 1
    | Itv _, _ -> -1

let equal e1 e2 = compare e1 e2 = 0

let pretty fmt = function
  | Itv i -> Int_interval.pretty fmt i
  | Float f -> Fval.pretty fmt f
  | Set s -> Int_set.pretty fmt s

let min_le_elt min elt =
  match min with
  | None -> true
  | Some m -> Int.le m elt

let max_ge_elt max elt =
  match max with
  | None -> true
  | Some m -> Int.ge m elt


let fail min max r modu =
  let bound fmt = function
    | None -> Format.fprintf fmt "--"
    | Some x -> Int.pretty fmt x
  in
  Kernel.fatal "Ival: broken Itv, min=%a max=%a r=%a modu=%a"
    bound min bound max Int.pretty r Int.pretty modu

let is_safe_modulo r modu =
  (Int.ge r Int.zero ) && (Int.ge modu Int.one) && (Int.lt r modu)

let is_safe_bound bound r modu = match bound with
  | None -> true
  | Some m -> Int.equal (Int.e_rem m modu) r

(* Sanity check for Itv's arguments *)
let check min max r modu =
  if not (is_safe_modulo r modu
          && is_safe_bound min r modu
          && is_safe_bound max r modu)
  then fail min max r modu


let cardinal_zero_or_one = function
  | Itv _ -> false
  | Set s -> Int_set.cardinal s <= 1
  | Float f -> Fval.is_singleton f

let is_singleton_int v = match v with
  | Float _ | Itv _ -> false
  | Set s -> Int_set.cardinal s = 1

(* TODO *)
let is_bottom x = equal x bottom

let zero = Set Int_set.zero
let one = Set Int_set.one
let minus_one = Set Int_set.minus_one
let zero_or_one = Set Int_set.zero_or_one
let float_zeros = Float Fval.zeros

let positive_integers = Itv (Int_interval.inject_range (Some Int.zero) None)
let negative_integers = Itv (Int_interval.inject_range None (Some Int.zero))

let is_zero x = x == zero

let inject_singleton e = Set (Int_set.inject_singleton e)

let inject_float f =
  if Fval.(equal plus_zero f)
  then zero
  else Float f

let inject_float_interval flow fup =
  let flow = Fval.F.of_float flow in
  let fup = Fval.F.of_float fup in
  (* make sure that zero float is also zero int *)
  if Fval.F.equal Fval.F.plus_zero flow && Fval.F.equal Fval.F.plus_zero fup
  then zero
  else Float (Fval.inject Fval.Double flow fup)

(*  let minus_zero = Float (Fval.minus_zero, Fval.minus_zero) *)

let is_one = equal one

let project_float v =
  if is_zero v
  then Fval.plus_zero
  else
    match v with
    | Float f -> f
    | Itv _ | Set _ -> assert false (* by hypothesis that it is a float *)

let is_float = function
  | Float _ -> true
  | Itv _ -> false
  | Set _ as i -> equal zero i || equal bottom i

let is_int = function
  | Itv _ | Set _ -> true
  | Float _ -> false

let contains_zero = function
  | Itv i -> Int_interval.mem Int.zero i
  | Set s -> Int_set.mem Int.zero s >= 0
  | Float f -> Fval.contains_a_zero f

let contains_non_zero = function
  | Itv _ -> true (* at least two values *)
  | Set _ as s -> not (is_zero s || is_bottom s)
  | Float f -> Fval.contains_non_zero f


exception Not_Singleton_Int

let project_int = function
  | Set s ->
    if Int_set.cardinal s = 1 then Int_set.min s else raise Not_Singleton_Int
  | _ -> raise Not_Singleton_Int

let is_small_set = function
  | Set _ -> true
  | _ -> false

let project_small_set = function
  | Set a -> Some (Int_set.to_list a)
  | _ -> None

let cardinal = function
  | Itv i -> Int_interval.cardinal i
  | Set s -> Some (Int.of_int (Int_set.cardinal s))
  | Float f -> if Fval.is_singleton f then Some Int.one else None

let cardinal_estimate v ~size =
  match v with
  | Set s -> Int.of_int (Int_set.cardinal s)
  | Itv i -> Extlib.opt_conv (Int.two_power size) (Int_interval.cardinal i)
  | Float f ->
    if Fval.is_singleton f
    then Int.one
    else
      let bits_of_float =
        if Integer.(equal size (of_int 32))
        then Fval.bits_of_float32_list
        else if Integer.(equal size (of_int 64))
        then Fval.bits_of_float64_list
        else (fun _ -> [Int.zero, Int.pred (Int.two_power size)])
      in
      let bits_list = bits_of_float f in
      let count acc (min, max) = Int.add acc (Int.length min max) in
      List.fold_left count Int.zero bits_list

let cardinal_less_than v n =
  let c =
    match v with
    | Itv i -> Extlib.the ~exn:Not_less_than (Int_interval.cardinal i)
    | Set s -> Int.of_int (Int_set.cardinal s)
    | Float f ->
      if Fval.is_singleton f then Int.one else raise Not_less_than
  in
  if Int.le c (Int.of_int n)
  then Int.to_int c (* This is smaller than the original [n] *)
  else raise Not_less_than

let cardinal_is_less_than v n =
  match cardinal v with
  | None -> false
  | Some c -> Int.le c (Int.of_int n)

let make ~min ~max ~rem ~modu =
  match min, max with
  | Some mn, Some mx ->
    if Int.gt mx mn then
      let l = Int.succ (Int.e_div (Int.sub mx mn) modu) in
      if Int.le l !small_cardinal_Int
      then
        let l = Int.to_int l in
        let s = Array.make l Int.zero in
        let v = ref mn in
        let i = ref 0 in
        while (!i < l)
        do
          s.(!i) <- !v;
          v := Int.add modu !v;
          incr i
        done;
        assert (Int.equal !v (Int.add modu mx));
        Set (Int_set.inject_array s l)
      else Itv (Int_interval.make ~min ~max ~rem ~modu)
    else if Int.equal mx mn
    then inject_singleton mn
    else bottom
  | _ -> Itv (Int_interval.make ~min ~max ~rem ~modu)

let inject_top min max rem modu =
  check min max rem modu;
  make ~min ~max ~rem ~modu

let inject_interval ~min ~max ~rem:r ~modu =
  assert (is_safe_modulo r modu);
  let fix_bound fix bound = match bound with
    | None -> None
    | Some b -> Some (if Int.equal b (Int.e_rem r modu) then b else fix b)
  in
  let min = fix_bound (fun min -> Int.round_up_to_r ~min ~r ~modu) min
  and max = fix_bound (fun max -> Int.round_down_to_r ~max ~r ~modu) max in
  make ~min ~max ~rem:r ~modu


let inject_set_or_bottom = function
  | `Bottom -> bottom
  | `Value s -> Set s

let inject_itv_or_bottom = function
  | `Bottom -> bottom
  | `Value i ->
    match Int_interval.cardinal i with
    | None -> Itv i
    | Some card ->
      if Int.le card !small_cardinal_Int
      then
        let min, max, rem, modu = Int_interval.min_max_rem_modu i in
        make ~min ~max ~rem ~modu
      else Itv i


let subdiv_int v =
  match v with
  | Float _ -> raise Can_not_subdiv
  | Set s -> let s1, s2 = Int_set.subdivide s in Set s1, Set s2
  | Itv i ->
    let i1, i2 = Int_interval.subdivide i in
    (* Redo make in case an interval should be converted into a set. *)
    let t1 =
      let min, max, rem, modu = Int_interval.min_max_rem_modu i1 in
      make ~min ~max ~rem ~modu
    and t2 =
      let min, max, rem, modu = Int_interval.min_max_rem_modu i2 in
      make ~min ~max ~rem ~modu
    in
    t1, t2

let subdivide ~size = function
  | Float fval ->
    let fkind = match Integer.to_int size with
      | 32 -> Fval.Single
      | 64 -> Fval.Double
      | _ -> raise Can_not_subdiv (* see Value/Value#105 *)
    in
    let f1, f2 = Fval.subdiv_float_interval fkind fval in
    inject_float f1, inject_float f2
  | ival -> subdiv_int ival

let inject_range min max = inject_top min max Int.zero Int.one

let top_float = Float Fval.top
let top_single_precision_float = Float Fval.top

let make_top_from_set s =
  let min = Int_set.min s in
  let modu =
    Int_set.fold
      (fun acc x ->
         if Int.equal x min
         then acc
         else Int.pgcd (Int.sub x min) acc)
      Int.zero
      s
  in
  let rem = Int.e_rem min modu in
  let max = Some (Int_set.max s) in
  let min = Some min in
  min, max, rem, modu

let make_itv_from_set s =
  let min, max, rem, modu = make_top_from_set s in
  Int_interval.make ~min ~max ~rem ~modu

let make_itv = function
  | Itv i -> i
  | Set s -> make_itv_from_set s
  | Float _ -> Int_interval.top

let make_range = function
  | Itv i -> i
  | Set s ->
    let min, max = Int_set.min s, Int_set.max s in
    Int_interval.inject_range (Some min) (Some max)
  | Float _ -> Int_interval.top

let inject_pre_itv ~min ~max ~modu =
  let rem = Int.e_rem min modu in
  Itv (Int_interval.make ~min:(Some min) ~max:(Some max) ~rem ~modu)

let inject_set_or_top = function
  | `Set s -> Set s
  | `Top (min, max, modu) -> inject_pre_itv ~min ~max ~modu

let min_max_r_mod t =
  match t with
  | Set s ->
    assert (Int_set.cardinal s >= 2);
    make_top_from_set s
  | Itv i -> Int_interval.min_max_rem_modu i
  | Float _ -> None, None, Int.zero, Int.one

let min_and_max t =
  match t with
  | Set s ->
    let l = Int_set.cardinal s in
    if l = 0
    then raise Error_Bottom
    else Some (Int_set.min s), Some (Int_set.max s)
  | Itv i -> Int_interval.min_and_max i
  | Float _ -> None, None

let min_and_max_float t =
  match t with
  | Set _ when is_zero t -> Some (Fval.F.plus_zero, Fval.F.plus_zero), false
  | Float f -> Fval.min_and_max f
  | _ -> assert false

let has_greater_min_bound t1 t2 =
  if is_float t1 && is_float t2
  then Fval.has_greater_min_bound (project_float t1) (project_float t2)
  else
    let m1, _ = min_and_max t1 in
    let m2, _ = min_and_max t2 in
    match m1, m2 with
    | None, None -> 0
    | None, Some _ -> -1
    | Some _, None -> 1
    | Some m1, Some m2 -> Int.compare m1 m2

let has_smaller_max_bound t1 t2 =
  if is_float t1 && is_float t2
  then Fval.has_smaller_max_bound (project_float t1) (project_float t2)
  else
    let _, m1 = min_and_max t1 in
    let _, m2 = min_and_max t2 in
    match m1, m2 with
    | None, None -> 0
    | None, Some _ -> -1
    | Some _, None -> 1
    | Some m1, Some m2 -> Int.compare m2 m1

let widen (bitsize,(wh,fh)) t1 t2 =
  if equal t1 t2 || cardinal_zero_or_one t1 then t2
  else
    match t2 with
    | Float f2 ->
      let f1 = project_float t1 in
      let prec =
        if Integer.equal bitsize (Integer.of_int 32)
        then Float_sig.Single
        else if Integer.equal bitsize (Integer.of_int 64)
        then Float_sig.Double
        else if Integer.equal bitsize (Integer.of_int 128)
        then Float_sig.Long_Double
        else Float_sig.Single
      in
      Float (Fval.widen fh prec f1 f2)
    | Itv _ | Set _ ->
      let i1 = make_itv t1
      and i2 = make_itv t2 in
      inject_itv_or_bottom (`Value (Int_interval.widen (bitsize, wh) i1 i2))

let meet v1 v2 =
  if v1 == v2 then v1 else
    let result =
      match v1,v2 with
      | Itv i1, Itv i2 -> inject_itv_or_bottom (Int_interval.meet i1 i2)
      | Set s1 , Set s2 -> inject_set_or_bottom (Int_set.meet s1 s2)
      | Set s, Itv itv
      | Itv itv, Set s ->
        inject_set_or_bottom (Int_set.filter (fun i -> Int_interval.mem i itv) s)
      | Float(f1), Float(f2) -> begin
          match Fval.meet f1 f2 with
          | `Value f -> inject_float f
          | `Bottom -> bottom
        end
      | (Float f as ff), (Itv _ | Set _ as o)
      | (Itv _ | Set _ as o), (Float f as ff) ->
        if equal o top then ff
        else if contains_zero o && Fval.contains_plus_zero f then zero
        else bottom
    in
    (*      Format.printf "meet: %a /\\ %a -> %a@\n"
            pretty v1 pretty v2 pretty result;*)
    result

let intersects v1 v2 =
  v1 == v2 ||
  match v1, v2 with
  | Itv _, Itv _ -> not (is_bottom (meet v1 v2)) (* YYY: slightly inefficient *)
  | Set s1 , Set s2 -> Int_set.intersects s1 s2
  | Set s, Itv itv | Itv itv, Set s ->
    Int_set.exists (fun i -> Int_interval.mem i itv) s
  | Float f1, Float f2 -> begin
      match Fval.forward_comp Comp.Eq f1 f2 with
      | Comp.False -> false
      | Comp.True | Comp.Unknown -> true
    end
  | Float f, other | other, Float f ->
    equal top other || (Fval.contains_plus_zero f && contains_zero other)

let narrow v1 v2 =
  match v1, v2 with
  | Set s1, Set s2 -> inject_set_or_bottom (Int_set.narrow s1 s2)
  | Float _, Float _ | (Itv _| Set _), (Itv _ | Set _) ->
    meet v1 v2 (* meet is exact *)
  | v, (Itv _ as t) when equal t top -> v
  | (Itv _ as t), v when equal t top -> v
  | Float f, (Set _ as s) | (Set _ as s), Float f when is_zero s -> begin
      match Fval.narrow f Fval.zeros with
      | `Value f -> inject_float f
      | `Bottom -> bottom
    end
  | Float _, (Set _ | Itv _) | (Set _ | Itv _), Float _ ->
    (* ill-typed case. It is better to keep the operation symmetric *)
    top

let link v1 v2 = match v1, v2 with
  | Set s1, Set s2 -> inject_set_or_top (Int_set.link s1 s2)
  | Itv i1, Itv i2 -> Itv (Int_interval.link i1 i2)
  | Itv i, Set s | Set s, Itv i ->
    let min, max, rem, modu = Int_interval.min_max_rem_modu i in
    let move_bound add = function
      | None -> None
      | Some bound ->
        let cur = ref bound in
        Int_set.iter (fun e -> if Int.equal e (add !cur modu) then cur := e) s;
        Some !cur
    in
    let min = move_bound Int.sub min
    and max = move_bound Int.add max in
    inject_top min max rem modu
  | _ -> bottom


let join v1 v2 =
  let result =
    if v1 == v2 then v1 else
      match v1,v2 with
      | Itv i1, Itv i2 -> Itv (Int_interval.join i1 i2)
      | Set i1, Set i2 -> inject_set_or_top (Int_set.join i1 i2)
      | Set s, (Itv i as t)
      | (Itv i as t), Set s ->
        let min, max, r, modu = Int_interval.min_max_rem_modu i in
        let l = Int_set.cardinal s in
        if l = 0 then t
        else
          let f modu elt = Int.pgcd modu (Int.abs (Int.sub r elt)) in
          let modu = Int_set.fold f modu s in
          let rem = Int.e_rem r modu in
          let min = match min with
              None -> None
            | Some m -> Some (Int.min m (Int_set.min s))
          in
          let max = match max with
              None -> None
            | Some m -> Some (Int.max m (Int_set.max s))
          in
          check min max rem modu;
          Itv (Int_interval.make ~min ~max ~rem ~modu)
      | Float(f1), Float(f2) ->
        inject_float (Fval.join f1 f2)
      | Float (f) as ff, other | other, (Float (f) as ff) ->
        if is_zero other
        then inject_float (Fval.join Fval.plus_zero f)
        else if is_bottom other then ff
        else top
  in
  (*  Format.printf "mod_join %a %a -> %a@."
      pretty v1 pretty v2 pretty result; *)
  result

let complement_int_under ~size ~signed i =
  let e = Int.two_power_of_int (if signed then size - 1 else size) in
  let b = if signed then Int.neg e else Int.zero in
  let e = Int.pred e in
  let inject_range min max = `Value (inject_range (Some min) (Some max)) in
  match i with
  | Float _ -> `Bottom
  | Set [||] -> inject_range b e
  | Set set ->
    let l = Array.length set in
    let array = Array.make (l + 2) Int.zero in
    array.(0) <- b;
    Array.blit set 0 array 1 l;
    array.(l+1) <- e;
    let index = ref (-1) in
    let max_delta = ref Int.zero in
    for i = 0 to l do
      let delta = Int.sub array.(i+1) array.(i) in
      if Int.gt delta !max_delta then begin
        index := i;
        max_delta := delta
      end
    done;
    inject_range array.(!index) array.(!index + 1)
  | Top (min, max, _rem, _modu) ->
    match min, max with
    | None, None -> `Bottom
    | Some min, None -> inject_range b (Int.pred min)
    | None, Some max -> inject_range (Int.succ max) e
    | Some min, Some max ->
      let delta_min = Int.sub min b in
      let delta_max = Int.sub e max in
      if Int.le delta_min delta_max
      then inject_range (Int.succ max) e
      else inject_range b (Int.pred min)

let fold_int f v acc =
  match v with
  | Float _ -> raise Error_Top
  | Itv i -> Int_interval.fold_int f i acc
  | Set s -> Int_set.fold (fun acc x -> f x acc) acc s

let fold_enum f v acc =
  match v with
  | Float fl when Fval.is_singleton fl -> f v acc
  | Float _ -> raise Error_Top
  | Set _ | Itv _ -> fold_int (fun x acc -> f (inject_singleton x) acc) v acc

let is_included t1 t2 =
  (t1 == t2) ||
  match t1,t2 with
  | Set s, _ when Int_set.cardinal s = 0 -> true
  | Itv i1, Itv i2 -> Int_interval.is_included i1 i2
  | Itv _, Set _ -> false (* Itv _ represents more elements
                             than can be represented by Set _ *)
  | Set s, Itv i ->
    let min, max, rem, modu = Int_interval.min_max_rem_modu i in
    (* Inclusion of bounds is needed for the entire inclusion *)
    min_le_elt min (Int_set.min s) && max_ge_elt max (Int_set.max s)
    && (Int.equal Int.one modu (* Top side contains all integers, we're done *)
        || Int_set.for_all (fun x -> Int.equal (Int.e_rem x modu) rem) s)
  | Set s1, Set s2 -> Int_set.is_included s1 s2
  | Float f1, Float f2 -> Fval.is_included f1 f2
  | Float _, _ -> equal t2 top
  | Set _, Float f -> is_zero t1 && Fval.contains_plus_zero f
  | Itv _, Float _ -> false

let add_singleton_int i v = match v with
  | Float _ -> assert false
  | Set s -> Set (Int_set.add_singleton i s)
  | Itv itv -> Itv (Int_interval.add_singleton_int i itv)

let add_int v1 v2 =
  match v1,v2 with
  | Float _, _ | _, Float _ -> assert false
  | Set s1, Set s2 -> inject_set_or_top (Int_set.add s1 s2)
  | Itv i1, Itv i2 -> Itv (Int_interval.add i1 i2)
  | Set s, Itv i | Itv i, Set s ->
    let l = Int_set.cardinal s in
    if l = 0
    then bottom
    else if l = 1
    then (* only one element *)
      Itv (Int_interval.add_singleton_int (Int_set.min s) i)
    else
      Itv (Int_interval.add i (make_itv_from_set s))

let add_int_under v1 v2 = match v1,v2 with
  | Float _, _ | _, Float _ -> assert false
  | Set s1, Set s2 -> inject_set_or_top (Int_set.add_under s1 s2)
  | Itv i1, Itv i2 -> inject_itv_or_bottom (Int_interval.add_under i1 i2)
  | Set s, Itv i | Itv i, Set s ->
    let l = Int_set.cardinal s in
    if l = 0
    then bottom
    else
      begin
        if l <> 1
        then log_imprecision "Ival.add_int_under";
        (* This is precise if [s] has only one element. Otherwise, this is not worse
           than another computation. *)
        Itv (Int_interval.add_singleton_int (Int_set.min s) i)
      end


let neg_int v =
  match v with
  | Float _ -> assert false
  | Set s -> Set (Int_set.neg s)
  | Itv i -> Itv (Int_interval.neg i)

let sub_int v1 v2 = add_int v1 (neg_int v2)
let sub_int_under v1 v2 = add_int_under v1 (neg_int v2)

let min_int s =
  match s with
  | Itv i -> fst (Int_interval.min_and_max i)
  | Set s -> 
    if Int_set.cardinal s = 0
    then raise Error_Bottom
    else Some (Int_set.min s)
  | Float _ -> None


let max_int s =
  match s with
  | Itv i -> snd (Int_interval.min_and_max i)
  | Set s ->
    if Int_set.cardinal s = 0
    then raise Error_Bottom
    else Some (Int_set.max s)
  | Float _ -> None


(* TODO: rename this function to scale_int *)
let scale f v =
  if Int.is_zero f
  then zero
  else
    match v with
    | Float _ -> top
    | Itv i-> Itv (Int_interval.scale f i)
    | Set s -> Set (Int_set.scale f s)



let scale_div_common ~pos f v scale_interval degenerate_float =
  assert (not (Int.is_zero f));
  match v with
  | Itv i -> inject_itv_or_bottom (scale_interval ~pos f i)
  | Set s -> inject_set_or_bottom (Int_set.scale_div ~pos f s)
  | Float _ -> degenerate_float

let scale_div ~pos f v =
  let scale_div ~pos f x = `Value (Int_interval.scale_div ~pos f x) in
  scale_div_common ~pos f v scale_div top

let scale_div_under ~pos f v =
  (* TODO: a more precise result could be obtained by transforming
     Itv(min,max,r,m) into Itv(min,max,r/f,m/gcd(m,f)). But this is
     more complex to implement when pos or f is negative. *)
  scale_div_common ~pos f v Int_interval.scale_div_under bottom

let div_set x sy =
  Int_set.fold
    (fun acc elt ->
       if Int.is_zero elt
       then acc
       else join acc (scale_div ~pos:false elt x))
    bottom
    sy

let div x y =
  (*if (intersects y negative || intersects x negative) then ignore
    (CilE.warn_once "using 'round towards zero' semantics for '/',
    which only became specified in C99."); *)
  match y with
  | Set sy -> div_set x sy
  | Itv iy -> inject_itv_or_bottom (Int_interval.div (make_range x) iy)
  | Float _ -> assert false

(* [scale_rem ~pos:false f v] is an over-approximation of the set of
   elements [x mod f] for [x] in [v].

   [scale_rem ~pos:true f v] is an over-approximation of the set of
   elements [x e_rem f] for [x] in [v].
*)
let scale_rem ~pos f v =
  if Int.is_zero f then bottom
  else
    match v with
    | Itv i -> inject_itv_or_bottom (`Value (Int_interval.scale_rem ~pos f i))
    | Set s -> inject_set_or_top (Int_set.scale_rem ~pos f s)
    | Float _ -> top

let c_rem x y =
  match y with
  | Float _ -> top
  | Itv iy ->
    if is_bottom x then bottom
    else inject_itv_or_bottom (Int_interval.c_rem (make_range x) iy)
  | Set yy ->
    match x with
    | Set xx -> inject_set_or_top (Int_set.c_rem xx yy)
    | Float _ -> top
    | Itv _ ->
      let f acc y =
        join (scale_rem ~pos:false y x) acc
      in
      Int_set.fold f bottom yy

module AllValueHashtbl =
  Hashtbl.Make
    (struct
      type t = Int.t * bool * int
      let equal (a,b,c:t) (d,e,f:t) = b=e && c=f && Int.equal a d
      let hash (a,b,c:t) = 
        257 * (Hashtbl.hash b) + 17 * (Hashtbl.hash c) + Int.hash a
    end)

let all_values_table = AllValueHashtbl.create 7

let create_all_values_modu ~modu ~signed ~size =
  let t = modu, signed, size in
  try
    AllValueHashtbl.find all_values_table t
  with Not_found ->
    let mn, mx =
      if signed then
        let b = Int.two_power_of_int (size-1) in
        (Int.round_up_to_r ~min:(Int.neg b) ~modu ~r:Int.zero,
         Int.round_down_to_r ~max:(Int.pred b) ~modu ~r:Int.zero)
      else
        let b = Int.two_power_of_int size in
        Int.zero,
        Int.round_down_to_r ~max:(Int.pred b) ~modu ~r:Int.zero
    in
    let r = inject_top (Some mn) (Some mx) Int.zero modu in
    AllValueHashtbl.add all_values_table t r;
    r

let create_all_values ~signed ~size =
  if size <= !small_cardinal_log then
    (* We may need to create a set. Use slow path *)
    create_all_values_modu ~signed ~size ~modu:Int.one
  else
  if signed then
    let b = Int.two_power_of_int (size-1) in
    Itv (Int_interval.inject_range (Some (Int.neg b)) (Some (Int.pred b)))
  else
    let b = Int.two_power_of_int size in
    Itv (Int_interval.inject_range (Some Int.zero) (Some (Int.pred b)))

let big_int_64 = Int.of_int 64
let big_int_32 = Int.thirtytwo

let cast_int_to_int ~size ~signed value =
  if equal top value
  then create_all_values ~size:(Int.to_int size) ~signed
  else
    let result =
      let factor = Int.two_power size in
      let mask = Int.two_power (Int.pred size) in
      let rem_f value = Int.cast ~size ~signed ~value
      in
      let not_p_factor = Int.neg factor in
      let best_effort r m =
        let modu = Int.pgcd factor m in
        let rr = Int.e_rem r modu in
        let min_val = Some (if signed then
                              Int.round_up_to_r ~min:(Int.neg mask) ~r:rr ~modu
                            else
                              Int.round_up_to_r ~min:Int.zero ~r:rr ~modu)
        in
        let max_val = Some (if signed then
                              Int.round_down_to_r ~max:(Int.pred mask) ~r:rr ~modu
                            else
                              Int.round_down_to_r ~max:(Int.pred factor)
                                ~r:rr
                                ~modu)
        in
        inject_top min_val max_val rr modu
      in
      match value with
      | Itv i->
        begin
          let mn, mx, r, m = Int_interval.min_max_rem_modu i in
          match mn, mx with
          | Some mn, Some mx ->
            let highbits_mn,highbits_mx =
              if signed then
                Int.logand (Int.add mn mask) not_p_factor,
                Int.logand (Int.add mx mask) not_p_factor
              else
                Int.logand mn not_p_factor, Int.logand mx not_p_factor
            in
            if Int.equal highbits_mn highbits_mx
            then
              if Int.is_zero highbits_mn
              then value
              else
                let new_min = rem_f mn in
                let new_r = Int.e_rem new_min m in
                inject_top (Some new_min) (Some (rem_f mx)) new_r m
            else best_effort r m
          | _, _ -> best_effort r m
        end
      | Set s -> begin
          let all =
            create_all_values ~size:(Int.to_int size) ~signed
          in
          if is_included value all
          then value
          else Set (Int_set.map rem_f s)
        end
      | Float _ -> assert false
    in
    (* If sharing is no longer preserved, please change Cvalue.V.cast *)
    if equal result value then value else result

let reinterpret_float_as_int ~signed ~size f =
  let reinterpret_list l =
    let reinterpret_one (b, e) =
      let i = inject_range (Some b) (Some e) in
      cast_int_to_int ~size ~signed i
    in
    let l = List.map reinterpret_one l in
    List.fold_left join bottom l
  in
  if Int.equal size big_int_64
  then
    let itvs = Fval.bits_of_float64_list f in
    reinterpret_list itvs
  else
  if Int.equal size big_int_32
  then
    let itvs = Fval.bits_of_float32_list f in
    reinterpret_list itvs
  else top

let reinterpret_as_int ~size ~signed i =
  match i with
  | Set _ | Itv _ ->
    (* On integers, cast and reinterpretation are the same operation *)
    cast_int_to_int ~signed ~size i
  | Float f -> reinterpret_float_as_int ~signed ~size f

let cast_float_to_float fkind v =
  match v with
  | Float f ->
    begin match fkind with
      | Fval.Real | Fval.Long_Double | Fval.Double -> v
      | Fval.Single ->
        inject_float (Fval.round_to_single_precision_float f)
    end
  | Set _ when is_zero v -> zero
  | Set _ | Itv _ -> top_float


(* TODO rename to mul_int *)
let mul v1 v2 =
  (*    Format.printf "mul. Args: '%a' '%a'@\n" pretty v1 pretty v2; *)
  let result =
    if is_one v1 then v2 
    else if is_zero v2 || is_zero v1 then zero
    else if is_one v2 then v1 
    else
      match v1,v2 with
      | Float _, _ | _, Float _ ->
        top
      | Set s1, Set s2 -> inject_set_or_top (Int_set.mul s1 s2)
      | Itv i1, Itv i2 -> Itv (Int_interval.mul i1 i2)
      | Set s, Itv i | Itv i, Set s ->
        let l = Int_set.cardinal s in
        if l = 0
        then bottom
        else if l = 1
        then Itv (Int_interval.scale (Int_set.min s) i)
        else Itv (Int_interval.mul i (make_itv_from_set s))
  in
  (* Format.printf "mul. result : %a@\n" pretty result;*)
  result

(** Computes [x (op) ({y >= 0} * 2^n)], as an auxiliary function for
    [shift_left] and [shift_right]. [op] and [scale] must verify
    [scale a b == op (inject_singleton a) b] *)
let shift_aux scale op (x: t) (y: t) =
  let y = narrow (inject_range (Some Int.zero) None) y in
  try
    match y with
    | Set s ->
      Int_set.fold (fun acc n -> join acc (scale (Int.two_power n) x)) bottom s
    | _ ->
      let min_factor = Extlib.opt_map Int.two_power (min_int y) in
      let max_factor = Extlib.opt_map Int.two_power (max_int y) in
      let modu = match min_factor with None -> Int.one | Some m -> m in
      let factor = inject_top min_factor max_factor Int.zero modu in
      op x factor
  with Z.Overflow ->
    Lattice_messages.emit_imprecision emitter "Ival.shift_aux";
    (* We only preserve the sign of the result *)
    if is_included x positive_integers then positive_integers
    else
    if is_included x negative_integers then negative_integers
    else top

let shift_right x y = shift_aux (scale_div ~pos:true) div x y
let shift_left x y = shift_aux scale mul x y


let interp_boolean ~contains_zero ~contains_non_zero =
  match contains_zero, contains_non_zero with
  | true, true -> zero_or_one
  | true, false -> zero
  | false, true -> one
  | false, false -> bottom


module Infty = struct
  let lt0 = function
    | None -> true
    | Some a -> Int.lt a Int.zero

  let div a b = match a with
    | None -> None
    | Some a -> match b with
      | None -> Some Int.zero
      | Some b -> Some (Int.e_div a b)

  let neg = function
    | Some a -> Some (Int.neg a)
    | None -> None
end

let backward_mult_pos_left min_right max_right result =
  let min_res, max_res = min_and_max result in
  let min_left =
    Infty.div min_res (if Infty.lt0 min_res then Some min_right else max_right)
  and max_left =
    Infty.div max_res (if Infty.lt0 max_res then max_right else Some min_right)
  in
  inject_range min_left max_left

let backward_mult_neg_left min_right max_right result =
  backward_mult_pos_left (Integer.neg max_right) (Infty.neg min_right) (neg_int result)

let backward_mult_int_left ~right ~result =
  match min_and_max right with
  | None, None -> `Value None
  | Some a, Some b when a > b -> `Bottom

  | Some a, Some b when a = Int.zero && b = Int.zero ->
    if contains_zero result then `Value None else `Bottom

  | Some a, max when a > Int.zero ->
    `Value (Some (backward_mult_pos_left a max result))

  | Some a, max when a >= Int.zero ->
    if contains_zero result
    then `Value None
    else `Value (Some (backward_mult_pos_left Int.one max result))

  | min, Some b when b < Int.zero ->
    `Value (Some (backward_mult_neg_left min b result))

  | min, Some b when b = Int.zero ->
    if contains_zero result
    then `Value None
    else `Value (Some (backward_mult_neg_left min Int.minus_one result))

  | min, max ->
    if contains_zero result
    then `Value None
    else
      `Value (Some (join
                      (backward_mult_pos_left Int.one max result)
                      (backward_mult_neg_left min Int.one result)))


let backward_le_int max v =
  match v with
  | Float _ -> v
  | Set _ | Itv _ -> narrow v (Itv (Int_interval.inject_range None max))

let backward_ge_int min v =
  match v with
  | Float _ -> v
  | Set _ | Itv _ -> narrow v (Itv (Int_interval.inject_range min None))

let backward_lt_int max v = backward_le_int (Extlib.opt_map Int.pred max) v
let backward_gt_int min v = backward_ge_int (Extlib.opt_map Int.succ min) v

let diff_if_one value rem =
  match rem with
  | Set s when Int_set.cardinal s = 1 ->
    begin
      let v = Int_set.min s in
      match value with
      | Set s -> inject_set_or_bottom (Int_set.remove s v)
      | Float _ -> value
      | Itv i ->
        let min, max, rem, modu = Int_interval.min_max_rem_modu i in
        match min, max with
        | Some mn, _ when Int.equal v mn ->
          inject_top (Some (Int.add mn modu)) max rem modu
        | _, Some mx when Int.equal v mx ->
          inject_top min (Some (Int.sub mx modu)) rem modu
        | Some mn, Some mx when
            Int.equal (Int.sub mx mn) (Int.mul modu !small_cardinal_Int)
            && Int_interval.mem v i ->
          let r = ref mn in
          let array =
            Array.init !small_cardinal
              (fun _ ->
                 let c = !r in
                 let corrected_c = if Int.equal c v then Int.add c modu else c in
                 r := Int.add corrected_c modu;
                 corrected_c)
          in
          Set (Int_set.inject_array array !small_cardinal)
        | _, _ -> value
    end
  | _ -> value

let diff value rem =
  log_imprecision "Ival.diff";
  diff_if_one value rem

(* This function is an iterator, but it needs [diff_if_one] just above. *)
let fold_int_bounds f v acc =
  match v with
  | Float _ -> f v acc
  | Set _ | Itv _ ->
    if cardinal_zero_or_one v then f v acc
    else
      (* apply [f] to [b] and reduce [v] if [b] is finite,
         or return [v] and [acc] unchanged *)
      let on_bound b v acc = match b with
        | None -> v, acc
        | Some b ->
          let b = inject_singleton b in
          diff_if_one v b, f b acc
      in
      let min, max = min_and_max v in
      (* [v] has cardinal at least 2, so [min] and [max] are distinct *)
      let v, acc = on_bound min v acc in
      let v, acc = on_bound max v acc in
      (* but if the cardinal was 2, then this [v] may be bottom *)
      if equal v bottom then acc else f v acc


let backward_comp_int_left op l r =
  let open Comp in
  try
    match op with
    | Le -> backward_le_int (max_int r) l
    | Ge -> backward_ge_int (min_int r) l
    | Lt -> backward_lt_int (max_int r) l
    | Gt -> backward_gt_int (min_int r) l
    | Eq -> narrow l r
    | Ne -> diff_if_one l r
  with Error_Bottom (* raised by max_int *) -> bottom

let backward_comp_float_left_true op fkind f1 f2  =
  let f1 = project_float f1 in
  let f2 = project_float f2 in
  begin match Fval.backward_comp_left_true op fkind f1 f2 with
    | `Value f -> inject_float f
    | `Bottom -> bottom
  end

let backward_comp_float_left_false op fkind f1 f2  =
  let f1 = project_float f1 in
  let f2 = project_float f2 in
  begin match Fval.backward_comp_left_false op fkind f1 f2 with
    | `Value f -> inject_float f
    | `Bottom -> bottom
  end



let rec extract_bits ~start ~stop ~size v =
  match v with
  | Set s -> Set (Int_set.map (Int.extract_bits ~start ~stop) s)
  | Float f ->
    let inject (b, e) = inject_range (Some b) (Some e) in
    let itvs =
      if Int.equal size big_int_64 then
        List.map inject (Fval.bits_of_float64_list f)
      else if Int.equal size big_int_32 then
        List.map inject (Fval.bits_of_float32_list f)
      else (* long double *)
        [top]
    in
    let bits = List.map (extract_bits ~start ~stop ~size) itvs in
    List.fold_left join bottom bits
  | Itv _ as d ->
    try
      let dived = scale_div ~pos:true (Int.two_power start) d in
      scale_rem ~pos:true (Int.two_power (Int.length start stop)) dived
    with Z.Overflow ->
      Lattice_messages.emit_imprecision emitter "Ival.extract_bits";
      top
;;

let all_values ~size v =
  if Int.lt big_int_64 size then false
  (* values of this size cannot be enumerated anyway in C.
     They may occur while initializing large blocks of arrays.
  *)
  else
    match v with
    | Float _ -> false
    | Itv i ->
      begin
        let min, max, _, modu = Int_interval.min_max_rem_modu i in
        match min, max with
        | None, _ | _, None -> Int.is_one modu
        | Some mn, Some mx ->
          Int.is_one modu &&
          Int.le
            (Int.two_power size)
            (Int.length mn mx)
      end
    | Set s ->
      let siz = Int.to_int size in
      Int_set.cardinal s >= 1 lsl siz &&
      equal
        (cast_int_to_int ~size ~signed:false v)
        (create_all_values ~size:siz ~signed:false)

let compare_min_max min max =
  match min, max with
  | None,_ -> -1
  | _,None -> -1
  | Some min, Some max -> Int.compare min max

let compare_max_min max min =
  match max, min with
  | None,_ -> 1
  | _,None -> 1
  | Some max, Some min -> Int.compare max min

let forward_le_int i1 i2 =
  if compare_max_min (max_int i1) (min_int i2) <= 0 then Comp.True
  else if compare_min_max (min_int i1) (max_int i2) > 0 then Comp.False
  else Comp.Unknown

let forward_lt_int i1 i2 =
  if compare_max_min (max_int i1) (min_int i2) < 0 then Comp.True
  else if compare_min_max (min_int i1) (max_int i2) >= 0 then Comp.False
  else Comp.Unknown

let forward_eq_int i1 i2 =
  if cardinal_zero_or_one i1 && equal i1 i2 then Comp.True
  else if intersects i2 i2 then Comp.Unknown
  else Comp.False

let forward_comp_int op i1 i2 =
  let open Abstract_interp.Comp in
  match op with
  | Le -> forward_le_int i1 i2
  | Ge -> forward_le_int i2 i1
  | Lt -> forward_lt_int i1 i2
  | Gt -> forward_lt_int i2 i1
  | Eq -> forward_eq_int i1 i2
  | Ne -> inv_truth (forward_eq_int i1 i2)

let rehash x = 
  match x with
  | Set s -> Set (Int_set.rehash s)
  | _ -> x

include (
  Datatype.Make_with_collections
    (struct
      type ival = t
      type t = ival
      let name = Int.name ^ " lattice_mod"
      open Structural_descr
      let structural_descr =
        let s_int = Descr.str Int.descr in
        t_sum
          [|
            [| pack (t_array s_int) |];
            [| Fval.packed_descr |];
            [| Int_interval.packed_descr |]
          |]
      let reprs = [ top ; bottom ]
      let equal = equal
      let compare = compare
      let hash = hash
      let pretty = pretty
      let rehash = rehash
      let internal_pretty_code = Datatype.pp_fail
      let mem_project = Datatype.never_any_project
      let copy = Datatype.undefined
      let varname = Datatype.undefined
    end):
    Datatype.S_with_collections with type t := t)

let scale_int_base factor v = match factor with
  | Int_Base.Top -> top
  | Int_Base.Value f -> scale f v

type overflow_float_to_int =
  | FtI_Ok of Int.t (* Value in range *)
  | FtI_Overflow of Floating_point.sign (* Overflow in the corresponding
                                           direction *)

let cast_float_to_int_non_nan ~signed ~size (min, max) =
  let all = create_all_values ~size ~signed in
  let min_all = Extlib.the (min_int all) in
  let max_all = Extlib.the (max_int all) in
  let conv f =
    try
      (* truncate_to_integer returns an integer that fits in a 64 bits
         integer, but might not fit in [size, sized] *)
      let i = Floating_point.truncate_to_integer f in
      if Int.ge i min_all then
        if Int.le i max_all then FtI_Ok i
        else FtI_Overflow Floating_point.Pos
      else FtI_Overflow Floating_point.Neg
    with Floating_point.Float_Non_representable_as_Int64 sign ->
      FtI_Overflow sign
  in
  let min_int = conv (Fval.F.to_float min) in
  let max_int = conv (Fval.F.to_float max) in
  match min_int, max_int with
  | FtI_Ok min_int, FtI_Ok max_int -> (* no overflow *)
    inject_range (Some min_int) (Some max_int)

  | FtI_Overflow Floating_point.Neg, FtI_Ok max_int -> (* one overflow *)
    inject_range (Some min_all) (Some max_int)
  | FtI_Ok min_int, FtI_Overflow Floating_point.Pos -> (* one overflow *)
    inject_range (Some min_int) (Some max_all)

  (* two overflows *)
  | FtI_Overflow Floating_point.Neg, FtI_Overflow Floating_point.Pos ->
    inject_range (Some min_all) (Some max_all)

  (* Completely out of range *)
  | FtI_Overflow Floating_point.Pos, FtI_Overflow Floating_point.Pos
  | FtI_Overflow Floating_point.Neg, FtI_Overflow Floating_point.Neg ->
    bottom

  | FtI_Overflow Floating_point.Pos, FtI_Overflow Floating_point.Neg
  | FtI_Overflow Floating_point.Pos, FtI_Ok _
  | FtI_Ok _, FtI_Overflow Floating_point.Neg ->
    assert false (* impossible if min-max are correct *)

let cast_float_to_int ~signed ~size iv =
  match Fval.min_and_max (project_float iv) with
  | Some (min, max), _nan -> cast_float_to_int_non_nan ~signed ~size (min, max)
  | None, _ -> bottom (* means NaN *)


(* These are the bounds of the range of integers that can be represented
   exactly as 64 bits double values *)
let double_min_exact_integer = Int.neg (Int.two_power_of_int 53)
let double_max_exact_integer = Int.two_power_of_int 53

(* same with 32 bits single values *)
let single_min_exact_integer = Int.neg (Int.two_power_of_int 24)
let single_max_exact_integer = Int.two_power_of_int 24

(* Same values expressed as double *)
let double_min_exact_integer_d = -. (2. ** 53.)
let double_max_exact_integer_d =     2. ** 53.
let single_min_exact_integer_d = -. (2. ** 24.)
let single_max_exact_integer_d =     2. ** 24.


(* finds all floating-point values [f] such that casting [f] to an integer
   type returns [i]. *)
let cast_float_to_int_inverse ~single_precision i =
  let exact_min, exact_max =
    if single_precision
    then single_min_exact_integer, single_max_exact_integer
    else double_min_exact_integer, double_max_exact_integer
  in
  let fkind = if single_precision then Fval.Single else Fval.Double in
  match min_and_max i with
  | Some min, Some max when Int.lt exact_min min && Int.lt max exact_max ->
    let minf =
      if Int.le min Int.zero then
        (* min is negative. We want to return [(float)((real)(min-1)+epsilon)],
           as converting this number to int will truncate all the fractional
           part (C99 6.3.1.4). Given [exact_min] and [exact_max], 1ulp
           is at most 1 here, so adding 1ulp will at most cancel the -1.
           Hence, we can use [next_float]. *)
        (* This float is finite because min is small enough *)
        Fval.F.next_float fkind (Int.to_float (Int.pred min))
      else (* min is positive. Since casting truncates towards 0,
              [(int)((real)min-epsilon)] would return [min-1]. Hence, we can
              simply return the float corresponding to [min] -- which can be
              represented precisely given [exact_min] and [exact_max]. *)
        Int.to_float min 
    in
    (* All operations are dual w.r.t. the min bound. *)
    let maxf =
      if Int.le Int.zero max
      then
        (* This float is finite because max is big enough *)
        Fval.F.prev_float fkind (Int.to_float (Int.succ max))
      else Int.to_float max
    in
    assert (Fval.F.is_finite (Fval.F.of_float minf));
    assert (Fval.F.is_finite (Fval.F.of_float maxf));
    Float (Fval.inject fkind (Fval.F.of_float minf) (Fval.F.of_float maxf))
  | _ -> if single_precision then top_single_precision_float else top_float


let cast_int_to_float_inverse_not_nan ~single_precision (min, max) =
  (* We restrict ourselves to (min,max) \in [exact_min, exact_max]. Outside of
     this range, the conversion int -> float is not exact, and the operation
     is more involved. *)
  let exact_min, exact_max =
    if single_precision
    then single_min_exact_integer_d, single_max_exact_integer_d
    else double_min_exact_integer_d, double_max_exact_integer_d
  in
  (* We find the integer range included in [f] *)
  let min = Fval.F.to_float min in
  let max = Fval.F.to_float max in
  if exact_min <= min && max <= exact_max then
    (* Round to integers in the proper direction: discard the non-floating-point
       values on each extremity. *)
    let min = ceil min in
    let max = floor max in
    let conv f = try  Some (Integer.of_float f) with Z.Overflow -> None in
    let r = inject_range (conv min) (conv max) in
    (* Kernel.result "Cast I->F inv:  %a -> %a@." pretty f pretty r; *)
    r
  else top (* Approximate *)

let cast_int_to_float_inverse ~single_precision f =
  match min_and_max_float f with
  | None, _ -> (* NaN *) bottom (* a cast of NaN to int is fully undefined *)
  | Some (min, max), _ (*we can disregard the NaN boolean for the same reason *)
    ->
    cast_int_to_float_inverse_not_nan ~single_precision (min, max)

let of_int i = inject_singleton (Int.of_int i)
let of_int64 i = inject_singleton (Int.of_int64 i)


(* This function always succeeds without alarms for C integers, because they
   always fit within a float32. *)
let cast_int_to_float fkind v =
  let min,max = min_and_max v in
  inject_float (Fval.cast_int_to_float fkind min max)

let reinterpret_as_float kind i =
  match i with
  | Float _ ->  i
  | Set _ when is_zero i || is_bottom i -> i
  | Itv _ | Set _ ->
    (* Reinterpret a range of integers as a range of floats.
       Float are ordered this way :
       if [min_i], [max_i] are the bounds of the signed integer type that
       has the same number of bits as the floating point type, and [min_f]
       [max_f] are the integer representation of the most negative and most
       positive finite float of the type, and < is signed integer comparison,
       we have: min_i < min_f <  min_f+1  < -1 <  0 < max_f <  max_f+1  < max_i
                 |        |       |          |    |      |       |          |
                 --finite--       -not finite-    -finite-       -not finite-
                 |        |       |<--------->    |      |       |<--------->
                -0.     -max    -inf   NaNs      +0.    max     inf   NaNs
       The float are of the same sign as the integer they convert into.
       Furthermore, the conversion function is increasing on the positive
       interval, and decreasing on the negative one. *)
    let reinterpret size kind conv min_f max_f =
      let size = Integer.of_int size in
      let i = cast_int_to_int ~size ~signed:true i in
      (* Intersect [i'] with [i], and return the (finite) bounds directly. *)
      let bounds_narrow i' =
        let r = narrow i i' in
        if is_bottom r then `Bottom
        else
          match min_and_max r with
          | None, _ | _, None -> assert false (* i is finite thanks to cast *)
          | Some b, Some e -> `Value (b, e)
      in
      let s_max_f = Int.succ max_f (* neg inf *) in
      let s_min_f = Int.succ min_f (* pos inf *) in
      let s_s_max_f = Int.succ s_max_f (* first 'positive' NaN *) in
      let s_s_min_f = Int.succ s_min_f (* first 'negative' NaN  *) in
      (* positive floats *)
      let f_pos = inject_range (Some Integer.zero) (Some s_max_f) in
      (* negative floats *)
      let f_neg = inject_range None (Some s_min_f) in
      (* 'positive' NaNs *)
      let nan_pos = inject_range (Some s_s_max_f) None in
      (* 'negative' NaNs *)
      let nan_neg = inject_range (Some s_s_min_f) (Some Int.minus_one) in
      let nan = (* at least one NaN somewhere *)
        if intersects i nan_pos || intersects i nan_neg
        then [`Value Fval.nan]
        else []
      in
      let open Bottom in
      let range mn mx = Fval.inject kind (conv mn) (conv mx) in
      (* convert positive floats; increasing on positive range *)
      let pos = bounds_narrow f_pos >>-: (fun (b, e) -> range b e) in
      (* convert negative floats; decreasing on negative range *)
      let neg = bounds_narrow f_neg >>-: (fun (b, e) -> range e b) in
      let f = Bottom.join_list Fval.join (pos :: neg :: nan) in
      inject_float (Bottom.non_bottom f)
    in
    let open Floating_point in
    match kind with
    | Cil_types.FDouble ->
      let conv v = Fval.F.of_float (Int64.float_of_bits (Int.to_int64 v)) in
      reinterpret
        64 Fval.Double conv bits_of_most_negative_double bits_of_max_double
    | Cil_types.FFloat ->
      let conv v = Fval.F.of_float(Int32.float_of_bits (Int.to_int32 v)) in
      reinterpret
        32 Fval.Single conv bits_of_most_negative_float bits_of_max_float
    | Cil_types.FLongDouble ->
      (* currently always imprecise *)
      top_float

let overlaps ~partial ~size t1 t2 =
  let diff = sub_int t1 t2 in
  match diff with
  | Set array ->
    not (Int_set.for_all
           (fun i -> Int.ge (Int.abs i) size || (partial && Int.is_zero i))
           array)
  | Itv i ->
    let min, max = Int_interval.min_and_max i in
    let pred_size = Int.pred size in
    min_le_elt min pred_size && max_ge_elt max (Int.neg pred_size)
  | Float _ -> assert false



(* ------------------------------------------------------------------------ *)
(* --- Bitwise operators                                                --- *)
(* ------------------------------------------------------------------------ *)

(* --- Bit lattice --- *)

type bit_value = On | Off | Both

module Bit =
struct
  type t = bit_value

  let to_string = function
    | Off -> "0"
    | On -> "1"
    | Both -> "T"

  let _pretty (fmt : Format.formatter) (b :t) =
    Format.pp_print_string fmt (to_string b)

  let union (b1 : t) (b2 : t) : t =
    if b1 = b2 then b1 else Both

  let not : t -> t = function
    | On -> Off
    | Off -> On
    | Both -> Both
end


(* --- Bit operators --- *)

module type BitOperator =
sig
  (* Printable version of the operator *)
  val representation : string
  (* forward is given here as the lifted function of some bit operator op
     where op
     1. is assumed to be commutative (backward functions do not assume the
        position of the arguments)
     2. must ensure  0 op 0 = 0  as otherwise applying op on a sign bit may
        produce a negative result from two positive operands; but we don't
        want to produce a negative result when the operation is unsigned which
        we don't know unless one of the operands is negative;
     3. is not constant, otherwise nothing of all of this makes sense.
     forward is defined as
     forward b1 b2 = { x1 op x2 | x1 \in b1, x2 \in b2 } *)
  val forward : bit_value -> bit_value -> bit_value
  (* backward_off b = { x | \exist y \in b . x op y = y op x = 1 } *)
  val backward_off : bit_value -> bit_value
  (* backward_on b = { x | \exist y \in b . x op y = y op x = 0 } *)
  val backward_on : bit_value -> bit_value
end

module And : BitOperator =
struct
  let representation = "&"

  let forward v1 v2 =
    match v1 with
    | Off -> Off
    | On -> v2
    | Both -> if v2 = Off then Off else Both

  let backward_off = function
    | (Off | Both) -> Both
    | On -> Off

  let backward_on = function
    | Off -> assert false
    | (On | Both) -> On
end

module Or : BitOperator =
struct
  let representation = "|"

  let forward v1 v2 =
    match v1 with
    | On -> On
    | Off -> v2
    | Both -> if v2 = On then On else Both

  let backward_off = function
    | On -> assert false
    | (Off | Both) -> Off

  let backward_on = function
    | (On | Both) -> Both
    | Off -> On
end

module Xor : BitOperator =
struct
  let representation = "^"

  let forward v1 v2 =
    match v1 with
    | Both -> Both
    | Off -> v2
    | On -> Bit.not v2

  let backward_on v = Bit.not v

  let backward_off v = v
end


(* --- Bit extraction and mutation --- *)

let significant_bits (v : t) : int option =
  match min_and_max v with
  | None, _ | _, None -> None
  | Some l, Some u -> Some (max (Z.numbits l) (Z.numbits u))

let extract_sign (v : t) : bit_value =
  match min_and_max v with
  | _, Some u when Int.(lt u zero) -> On
  | Some l, _ when Int.(ge l zero) -> Off
  | _, _ -> Both

let extract_bit (i : int) (v : t) : bit_value =
  let bit_value x = if Z.testbit x i then On else Off in
  match v with
  | Float _ -> Both
  | Set s -> Int_set.map_reduce bit_value Bit.union s
  | Itv itv ->
    match Int_interval.min_and_max itv with
    | None, _ | _, None -> Both
    | Some l, Some u ->
      (* It does not take modulo into account *)
      if Int.(ge (sub u l) (two_power_of_int i)) (* u - l >= mask *)
      then Both
      else Bit.union (bit_value l) (bit_value u)

let reduce_sign (v : t) (b : bit_value) : t =
  match b with
  | Both -> v
  | On ->
    begin match v with
      | Float _ -> v
      | Set s -> inject_set_or_bottom (Int_set.filter Int.(gt zero) s)
      | Itv itv -> inject_itv_or_bottom (Int_interval.reduce_sign itv true)
    end
  | Off ->
    begin match v with
      | Float _ -> v
      | Set s -> inject_set_or_bottom (Int_set.filter Int.(le zero) s)
      | Itv itv -> inject_itv_or_bottom (Int_interval.reduce_sign itv false)
    end

let reduce_bit (i : int) (v : t) (b : bit_value) : t =
  let bit_value x = if Z.testbit x i then On else Off in
  if b = Both
  then v
  else match v with
    | Float _ -> v
    | Set s -> inject_set_or_bottom (Int_set.filter (fun x -> bit_value x = b) s)
    | Itv itv -> inject_itv_or_bottom (Int_interval.reduce_bit i itv (b = On))

type bit = Sign | Bit of int

let extract_bit = function
  | Sign -> extract_sign
  | Bit i -> extract_bit i

let set_bit_on ~size bit =
  let mask = match bit with
    | Sign -> Int.(neg (two_power_of_int size))
    | Bit i -> Int.(two_power_of_int i)
  in
  fun v -> Int.logor mask v

let reduce_bit = function
  | Sign -> reduce_sign
  | Bit i -> reduce_bit i

(* --- Bitwise binary operators --- *)

module BitwiseOperator (Op : BitOperator) =
struct

  let backward (b : bit_value) = function
    | On -> Op.backward_on b
    | Off -> Op.backward_off b
    | Both -> assert false

  (** Bit masks are composed of an array of significant bit values where index 0
      represents the lowest bit, and a single bit_value to represent the
      possible leading bits. *)
  type bit_mask = bit_value array * bit_value

  (* Converts an integer [x] into a bit array of size [n]. *)
  let int_to_bit_array n (x : Int.t) =
    let make i = if Z.testbit x i then On else Off in
    Array.init n make

  (* Computes a bit_mask for the lowest bits of an ival, using the modulo
     information for non singleton values. *)
  let low_bit_mask : t -> bit_mask = function
    | Set s when Int_set.cardinal s = 0 -> raise Error_Bottom
    | Set s when Int_set.cardinal s = 1 -> (* singleton : build a full mask  *)
      let x = Int_set.min s in
      let n = Z.numbits x in
      int_to_bit_array n x, if Int.(ge x zero) then Off else On
    | v ->
      let _,_,r,modu = min_max_r_mod v in (* requires cardinal > 1 *)
      (* Find how much [modu] can be divided by two. *)
      let n = Z.trailing_zeros modu in
      int_to_bit_array n r, Both

  (* Computes a remainder and modulo for the result of [v1 op v2]. *)
  let compute_modulo v1 v2 =
    let b1, s1 = low_bit_mask v1
    and b2, s2 = low_bit_mask v2 in
    let size = max (Array.length b1) (Array.length b2) in
    (* Sets the [i] nth bits of [rem] until an uncertainty appears. *)
    let rec step i rem =
      let b1 = try b1.(i) with _ -> s1
      and b2 = try b2.(i) with _ -> s2 in
      let b = Op.forward b1 b2 in
      if i >= size || b = Both
      then rem, Int.two_power_of_int i
      else
        (* [rem] starts at 0, so we only need to turn on the 1 bits. *)
        let rem = if b = On then set_bit_on ~size (Bit i) rem else rem in
        step (i+1) rem
    in
    step 0 Int.zero

  (* The number of bits on which the result should be significant *)
  let result_size (v1 : t) (v2 : t) : int option =
    let n1 = significant_bits v1 and n2 = significant_bits v2 in
    let n1_greater =
      match n1, n2 with
      | None, _ -> true
      | _, None -> false
      | Some n1, Some n2 -> n1 >= n2
    in
    (* whether n1 or n2 is greater, look if the sign bit oped with anything is
       not constant. If it is constant, then the highest bits are irrelevant. *)
    if n1_greater
    then if Op.forward Both (extract_sign v2) = Both then n1 else n2
    else if Op.forward (extract_sign v1) Both = Both then n2 else n1

  exception Do_not_fit_small_sets

  (* Try to build a small set.
     It is basically enumerating the possible results, by choosing the possible
     bits from left to right. This function aborts if it ever exceeds the small
     set size. The algorithm is probably not complete, as it is not always
     possible to reduce the operands leading to a result (without an
     exponential cost)  meaning that sometimes small sets can be obtained but
     the algorithm will fail to find them. *)
  let compute_small_set ~size (v1 : t) (v2 : t) (r : Int.t) (modu : Int.t) =
    let set_bit i acc (r, v1, v2) =
      let b1 = extract_bit i v1
      and b2 = extract_bit i v2 in
      match Op.forward b1 b2 with
      | On -> (set_bit_on ~size i r, v1, v2) :: acc
      | Off -> (r, v1, v2) :: acc
      | Both ->
        let v1_off = reduce_bit i v1 (Op.backward_off b2)
        and v2_off = reduce_bit i v2 (Op.backward_off b1) in
        let v1_on = reduce_bit i v1 (Op.backward_on b2)
        and v2_on = reduce_bit i v2 (Op.backward_on b1) in
        (set_bit_on ~size i r, v1_on, v2_on) :: (r, v1_off, v2_off) :: acc
    in
    let acc = ref (set_bit Sign [] (r, v1, v2)) in
    for i = size - 1 downto Z.numbits modu - 1 do
      acc := List.fold_left (set_bit (Bit i)) [] !acc;
      if List.length !acc > !small_cardinal then raise Do_not_fit_small_sets
    done;
    let o = List.fold_left (fun o (r,_,_) -> O.add r o) O.empty !acc in
    let cardinal = O.cardinal o in
    if cardinal = 0 then bottom else
      let a = Array.make cardinal Int.zero in
      let i = ref 0 in
      O.iter (fun e -> a.(!i) <- e; incr i) o;
      Set (Int_set.inject_array a cardinal)

  (* If lower is true (resp. false), compute the lower (resp. upper) bound of
     the result interval when applying the bitwise operator to [v1] and [v2].
     [size] is the number of bits of the result.
     This function should be exact when the operands are small sets or tops
     with modulo 1. Otherwise, it is an overapproximation of the bound. *)
  let compute_bound ~size v1 v2 lower =
    (* Sets the [i]-nth bit of the currently computed bound [r] of [v1 op v2].
       If possible, reduces [v1] and [v2] accordingly. *)
    let set_bit i (r, v1, v2) =
      let b1 = extract_bit i v1
      and b2 = extract_bit i v2 in
      let b, v1, v2 =
        match Op.forward b1 b2 with
        | On | Off as b -> b, v1, v2 (* Constant bit, no reduction. *)
        | Both ->
          (* Choose the best bit for the searched bound, and reduces [v1] and
             [v2] accordingly. *)
          let b = match i with
            | Sign -> if lower then On else Off
            | Bit _ -> if lower then Off else On
          in
          let v1 = reduce_bit i v1 (backward b2 b)
          and v2 = reduce_bit i v2 (backward b1 b) in
          b, v1, v2
      in
      (* Only sets 1 bit, as [r] is 0 at the beginning. *)
      let r = if b = On then set_bit_on ~size i r else r in
      r, v1, v2
    in
    (* The result is 0 at the beginning, and [set_bit] turns on the 1 bits. *)
    let r = ref (Int.zero, v1, v2) in
    (* Sets the sign bit, and then the bits from size to 0. *)
    r := set_bit Sign !r;
    for i = (size - 1) downto 0 do
      r := set_bit (Bit i) !r;
    done;
    let bound, _v1, _v2 = !r in
    bound

  let bitwise_forward (v1 : t) (v2 : t) : t =
    try
      let r, modu = compute_modulo v1 v2 in
      match result_size v1 v2 with
      | None ->
        (* We could do better here, as one of the bound may be finite. However,
           this case should occur rarely or not at all. *)
        inject_interval None None r modu
      | Some size ->
        try compute_small_set ~size v1 v2 r modu
        with Do_not_fit_small_sets ->
          let min = compute_bound ~size v1 v2 true
          and max = compute_bound ~size v1 v2 false in
          inject_interval (Some min) (Some max) r modu
    with Error_Bottom -> bottom
end

let bitwise_or = let module M = BitwiseOperator (Or) in M.bitwise_forward
let bitwise_and = let module M = BitwiseOperator (And) in M.bitwise_forward
let bitwise_xor = let module M = BitwiseOperator (Xor) in M.bitwise_forward


(* --- Bitwise not --- *)

let bitwise_signed_not v =
  match v with
  | Float _ -> assert false
  | Itv _ -> add_int (neg_int v) minus_one (* [-v - 1] *)
  | Set s -> Set (Int_set.bitwise_signed_not s)

let bitwise_unsigned_not ~size v =
  let size = Int.of_int size in
  cast_int_to_int ~size ~signed:false (bitwise_signed_not v)

let bitwise_not ~size ~signed v =
  if signed then
    bitwise_signed_not v
  else
    bitwise_unsigned_not ~size v

let pretty_debug = pretty
let name = "ival"

(*
Local Variables:
compile-command: "make -C ../../.."
End:
*)
