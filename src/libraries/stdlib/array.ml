(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

include Stdlib.Array

let hash hash_elt a =
  let max = max 15 ((length a) - 1) in
  let acc = ref 1 in
  for i = 0 to max do acc := 257 * !acc + hash_elt (get a i) done;
  !acc

let pretty pp_elt fmt a =
  Format.fprintf fmt "(@[<hv 2>[| %t |]@])"
    (fun fmt ->
       let length = length a in
       match length with
       | 0 -> ()
       | _ -> (Format.fprintf fmt "%a" pp_elt (get a 0);
               for i = 1 to (length - 1) do
                 Format.fprintf fmt ";@;%a" pp_elt (get a i)
               done))
