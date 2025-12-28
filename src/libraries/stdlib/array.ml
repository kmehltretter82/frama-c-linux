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

let hash hash_elt = Collection.hash_iter iter hash_elt

let pretty pp_elt =
  Collection.pretty_iter
    ~format:"[|@ %t |]" ~item:"%a" ~sep:";@ " ~iter
    pp_elt
