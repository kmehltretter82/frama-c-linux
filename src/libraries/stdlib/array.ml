(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

include Stdlib.Array

let equal f a1 a2 =
  let exception Early_exit of int in
  let size = length a1 in
  if length a2 != size then false
  else try
      for i = 0 to size - 1 do
        if not (f (get a1 i) (get a2 i)) then raise (Early_exit 0)
      done;
      true
    with Early_exit _ -> false

let compare f a1 a2 =
  let exception Early_exit of int in
  let size1 = length a1 and size2 = length a2 in
  if size1 < size2 then -1
  else if size2 > size1 then 1
  else try
      for i = 0 to size1 do
        let n = f (get a1 i) (get a2 i) in
        if n != 0 then raise (Early_exit n)
      done;
      0
    with Early_exit n -> n

let fold f l acc =
  fold_left (fun acc x -> f x acc) acc l

let hash hash_elt = Collection.hash_iter iter hash_elt

let pretty pp_elt =
  Collection.pretty_iter
    ~format:"[|@ %t |]" ~item:"%a" ~sep:";@ " ~iter
    pp_elt
