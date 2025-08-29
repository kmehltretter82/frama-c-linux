(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

module Minimal = struct
  type 'a t = 'a option
  let return v = Some v
  let bind f m = Stdlib.Option.bind m f
  let product l r = match l, r with Some l, Some r -> Some (l, r) | _ -> None
end

include Monad.Make_based_on_bind_with_product (Minimal)

include Stdlib.Option

let bind = Minimal.bind
