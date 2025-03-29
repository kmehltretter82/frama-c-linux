(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

module L = Stdlib.List

module Minimal = struct
  type 'a t = 'a list
  let return   x = [ x ]
  let map   f xs = L.map f xs
  let flatten xs = L.flatten xs
  let product ls rs = L.combine ls rs
  let product ls rs = L.rev @@
    L.fold_left
      (fun acc_l l -> L.fold_left (fun acc_r r -> (l,r)::acc_r) acc_l rs)
      []
      ls
end

include Monad.Make_based_on_map_with_product (Minimal)

include Stdlib.List
