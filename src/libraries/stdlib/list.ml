(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

module Minimal = struct
  type 'a t = 'a list
  let return   x = [ x ]
  let map   f xs = Stdlib.List.map f xs
  let flatten xs = Stdlib.List.flatten xs
  let product ls rs =
    let pair l = map (fun r -> (l, r)) rs in
    Stdlib.List.concat_map pair ls
end

include Monad.Make_based_on_map_with_product (Minimal)

include Stdlib.List

let fold f l acc =
  fold_left (fun acc x -> f x acc) acc l

let hash hash_elt = Collection.hash_iter iter hash_elt

let pretty pp_elt =
  Collection.pretty_iter
    ~format:"[ %t ]" ~item:"%a" ~sep:";@ " ~iter
    pp_elt
