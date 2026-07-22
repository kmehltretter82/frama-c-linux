(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(* -------------------------------------------------------------------------- *)
(* --- Tau & Sort Manipulations                                           --- *)
(* -------------------------------------------------------------------------- *)

open Logic

let rec of_poly alpha = function
  | Prop -> Sprop
  | Bool -> Sbool
  | Int -> Sint
  | Real -> Sreal
  | Tvar x -> alpha x
  | Data _ -> Sdata
  | Array(_,d) -> Sarray (of_poly alpha d)

let of_tau t = of_poly (fun _ -> Sdata) t

let rec merge a b =
  match a,b with
  | Sprop , _ | _ , Sprop -> Sprop
  | Sbool , _ | _ , Sbool -> Sbool
  | Sarray x , Sarray y -> Sarray (merge x y)
  | Sarray _ , _ | _ , Sarray _ -> Sdata
  | Sint , Sint -> Sint
  | Sint , Sreal | Sreal , Sint -> Sreal
  | Sreal , Sreal -> Sreal
  | Sdata , _ | _ , Sdata -> Sdata

let image = function Sarray s -> s | _ -> Sdata

let rec merge_list f s = function
  | [] -> s
  | x::xs ->
    if s = Sprop then Sprop
    else merge_list f (merge s (f x)) xs

let pretty fmt = function
  | Sprop -> Format.pp_print_string fmt "Prop"
  | Sbool -> Format.pp_print_string fmt "Bool"
  | Sdata -> Format.pp_print_string fmt "Term"
  | Sint -> Format.pp_print_string fmt "Int"
  | Sreal -> Format.pp_print_string fmt "Real"
  | Sarray _ -> Format.pp_print_string fmt "Array"

let basename = function
  | Sprop | Sbool -> "P"
  | Sdata -> "a"
  | Sint  -> "x"
  | Sreal -> "r"
  | Sarray _ -> "m"

let rec map_tau adt = function
  | Int -> Int
  | Real -> Real
  | Bool -> Bool
  | Prop -> Prop
  | Tvar _ as x -> x
  | Array(a,b) -> Array(map_tau adt a,map_tau adt b)
  | Data(a,ts) -> Data(adt a,List.map (map_tau adt) ts)

let rec map_element f = function
  | (E_none | E_true | E_false | E_int _) as elt -> elt
  | E_fun (a, es) -> E_fun(f a, List.map (map_element f) es)

let map_operator f op =
  { op with
    neutral = map_element f op.neutral ;
    absorbent = map_element f op.absorbent ;
  }

let map_category f = function
  | (Function | Constructor | Injection as op) -> op
  | Operator op -> Operator (map_operator f op)

let pp_data pdata ptau fmt a = function
  | [] -> pdata fmt a
  | [t] -> Format.fprintf fmt "%a %a" ptau t pdata a
  | t::ts ->
    Format.fprintf fmt "@[(@[<hov 2>%a" ptau t ;
    List.iter
      (fun t -> Format.fprintf fmt ",@,%a" ptau t) ts ;
    Format.fprintf fmt ")@]@ %a@]" pdata a

let pp_record pfield ptau fmt ?(opened=false) fts =
  Format.fprintf fmt "@[<hv 0>{@[<hv 2>" ;
  List.iter
    (fun (f,t) -> Format.fprintf fmt "@ @[<hov 2>%a : %a ;@]" pfield f ptau t)
    fts ;
  if opened then Format.fprintf fmt "@ ..." ;
  Format.fprintf fmt "@]@ }@]"

let pp_tvar fmt k =
  if 0 <= k && k < 26 then
    Format.fprintf fmt "'%c" (char_of_int (k + int_of_char 'a'))
  else
    Format.fprintf fmt "'%d" k

let rec pp_tau pvar pdata fmt = function
  | Int -> Format.pp_print_string fmt "int"
  | Real -> Format.pp_print_string fmt "real"
  | Bool -> Format.pp_print_string fmt "bool"
  | Prop -> Format.pp_print_string fmt "prop"
  | Tvar x -> pvar fmt x
  | Array(Int,te) ->
    Format.fprintf fmt "%a[]" (pp_tau pvar pdata) te
  | Array(tk,te) ->
    Format.fprintf fmt "%a[%a]"
      (pp_tau pvar pdata) te (pp_tau pvar pdata) tk
  | Data(a,ts) -> pp_data pdata (pp_tau pvar pdata) fmt a ts

let rec hash_tau hadt = function
  | Int -> 0
  | Real -> 1
  | Bool -> 2
  | Prop -> 3
  | Tvar k -> 4+k
  | Array(tk,te) ->
    7 * Hcons.hash_pair (hash_tau hadt tk) (hash_tau hadt te)
  | Data(a,te) ->
    11 * Hcons.hash_list (hash_tau hadt) (hadt a) te

let rec eq_tau cadt t1 t2 =
  match t1 , t2 with
  | (Bool|Int|Real|Prop|Tvar _) , (Bool|Int|Real|Prop|Tvar _) -> t1 = t2
  | Array(ta,tb) , Array(ta',tb') ->
    eq_tau cadt ta ta' && eq_tau cadt tb tb'
  | Array _ , _  | _ , Array _ -> false
  | Data(a,ts) , Data(b,ts') ->
    cadt a b && Hcons.equal_list (eq_tau cadt) ts ts'
  | Data _ , _ | _ , Data _ -> false

let rec compare_tau cadt t1 t2 =
  match t1 , t2 with
  | Bool , Bool -> 0
  | Bool , _ -> (-1)
  | _ , Bool -> 1
  | Int , Int -> 0
  | Int , _ -> (-1)
  | _ , Int -> 1
  | Real , Real -> 0
  | Real , _ -> (-1)
  | _ , Real -> 1
  | Prop , Prop -> 0
  | Prop , _ -> (-1)
  | _ , Prop -> 1
  | Tvar k , Tvar k' -> Stdlib.compare k k'
  | Tvar _ , _ -> (-1)
  | _ , Tvar _ -> 1
  | Array(ta,tb) , Array(ta',tb') ->
    let c = compare_tau cadt ta ta' in
    if c = 0 then compare_tau cadt tb tb' else c
  | Array _ , _ -> (-1)
  | _ , Array _ -> 1
  | Data(a,ts) , Data(b,ts') ->
    let c = cadt a b in
    if c = 0 then Hcons.compare_list (compare_tau cadt) ts ts' else c

module MakeTau(A : Data) =
struct

  type t = A.t datatype

  let equal = eq_tau A.equal
  let compare = compare_tau A.compare
  let hash = hash_tau A.hash
  let pretty = pp_tau pp_tvar A.pretty

  let name = Format.asprintf "%a" pretty
  let fullname = name

  let basename = function
    | Int -> "i"
    | Real -> "r"
    | Prop -> "p"
    | Bool -> "p"
    | Array _ -> "t"
    | Tvar 1 -> "a"
    | Tvar 2 -> "b"
    | Tvar 3 -> "c"
    | Tvar 4 -> "d"
    | Tvar 5 -> "e"
    | Tvar _ -> "f"
    | Data(a,_) -> A.basename a

end
