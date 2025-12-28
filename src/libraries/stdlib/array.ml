(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

include Stdlib.Array

let fold f l acc =
  fold_left (fun acc x -> f x acc) acc l

let hash hash_elt a =
  let max = max 15 ((length a) - 1) in
  let acc = ref 1 in
  for i = 0 to max do acc := 257 * !acc + hash_elt (get a i) done;
  !acc

let pretty pp_elt =
  Collection.pretty_iter
    ~format:"[|@ %t |]" ~item:"%a" ~sep:";@ " ~iter
    pp_elt
