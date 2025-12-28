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

let hash hash_elt l =
  (* Do not spend too much time hashing long lists... *)
  let exception Too_long of int in
  try
    snd (fold_left
           (fun (length,acc) d ->
              if length > 15 then raise (Too_long acc);
              length+1, 257 * acc + hash_elt d)
           (0,1) l)
  with Too_long n -> n

let pretty f fmt l =
  Format.fprintf fmt "(@[<hv 2>[ %t ]@])"
    (fun fmt ->
       let rec print fmt = function
         | [] -> ()
         | [ x ] -> Format.fprintf fmt "%a" f x
         | x :: l -> Format.fprintf fmt "%a;@;%a" f x print l
       in
       print fmt l)
