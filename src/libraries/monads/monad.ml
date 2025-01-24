(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2025                                               *)
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



(* Complete signature *)
module type S = sig
  type 'a t
  val return : 'a -> 'a t
  val flatten : 'a t t -> 'a t
  val map  : ('a -> 'b  ) -> 'a t -> 'b t
  val bind : ('a -> 'b t) -> 'a t -> 'b t
  module Operators : sig
    val ( >>-  ) : 'a t -> ('a -> 'b t) -> 'b t
    val ( let* ) : 'a t -> ('a -> 'b t) -> 'b t
    val ( >>-: ) : 'a t -> ('a -> 'b) -> 'b t
    val ( let+ ) : 'a t -> ('a -> 'b) -> 'b t
  end
end

(* Complete signature with a product *)
module type S_with_product = sig
  type 'a t
  val return : 'a -> 'a t
  val flatten : 'a t t -> 'a t
  val map  : ('a -> 'b  ) -> 'a t -> 'b t
  val bind : ('a -> 'b t) -> 'a t -> 'b t
  val product : 'a t -> 'b t -> ('a * 'b) t
  module Operators : sig
    val ( >>-  ) : 'a t -> ('a -> 'b t) -> 'b t
    val ( let* ) : 'a t -> ('a -> 'b t) -> 'b t
    val ( and* ) : 'a t -> 'b t -> ('a * 'b) t
    val ( >>-: ) : 'a t -> ('a -> 'b) -> 'b t
    val ( let+ ) : 'a t -> ('a -> 'b) -> 'b t
    val ( and+ ) : 'a t -> 'b t -> ('a * 'b) t
  end
end



(* Minimal signature based on bind *)
module type Based_on_bind = sig
  type 'a t
  val return : 'a -> 'a t
  val bind : ('a -> 'b t) -> 'a t -> 'b t
end

(* Minimal signature based on bind with product *)
module type Based_on_bind_with_product = sig
  type 'a t
  val return : 'a -> 'a t
  val bind : ('a -> 'b t) -> 'a t -> 'b t
  val product : 'a t -> 'b t -> ('a * 'b) t
end

(* Minimal definition based on map *)
module type Based_on_map = sig
  type 'a t
  val return : 'a -> 'a t
  val map : ('a -> 'b) -> 'a t -> 'b t
  val flatten : 'a t t -> 'a t
end

(* Minimal signature based on map with product *)
module type Based_on_map_with_product = sig
  type 'a t
  val return : 'a -> 'a t
  val map : ('a -> 'b) -> 'a t -> 'b t
  val flatten : 'a t t -> 'a t
  val product : 'a t -> 'b t -> ('a * 'b) t
end



(* Extend a based on bind minimal monad *)
module Make_based_on_bind (M : Based_on_bind) = struct
  type 'a t = 'a M.t
  let return x = M.return x
  let bind f m = M.bind f m
  let flatten m = bind (fun x -> x) m
  let map f m = bind (fun x -> return (f x)) m
  module Operators = struct
    let ( >>-  ) m f = bind f m
    let ( let* ) m f = bind f m
    let ( >>-: ) m f = map  f m
    let ( let+ ) m f = map  f m
  end
end

(* Extend a based on map minimal monad *)
module Make_based_on_map (M : Based_on_map) = struct
  type 'a t = 'a M.t
  let return x = M.return x
  let map f m = M.map f m
  let flatten m = M.flatten m
  let bind f m = flatten (map f m)
  module Operators = struct
    let ( >>-  ) m f = bind f m
    let ( let* ) m f = bind f m
    let ( >>-: ) m f = map  f m
    let ( let+ ) m f = map  f m
  end
end

(* Extend a based on bind monad with a product *)
module Make_based_on_bind_with_product (M : Based_on_bind_with_product) = struct
  type 'a t = 'a M.t
  let return x = M.return x
  let bind f m = M.bind f m
  let flatten m = bind (fun x -> x) m
  let map f m = bind (fun x -> return (f x)) m
  let product l r = M.product l r
  module Operators = struct
    let ( >>-  ) m f = bind f m
    let ( let* ) m f = bind f m
    let ( let+ ) m f = map  f m
    let ( >>-: ) m f = map  f m
    let ( and* ) l r = product l r
    let ( and+ ) l r = product l r
  end
end

(** Extend a based on map monad with a product *)
module Make_based_on_map_with_product (M : Based_on_map_with_product) = struct
  type 'a t = 'a M.t
  let return x = M.return x
  let map f m = M.map f m
  let flatten m = M.flatten m
  let bind f m = flatten (map f m)
  let product l r = M.product l r
  module Operators = struct
    let ( >>-  ) m f = bind f m
    let ( let* ) m f = bind f m
    let ( let+ ) m f = map  f m
    let ( >>-: ) m f = map  f m
    let ( and* ) l r = product l r
    let ( and+ ) l r = product l r
  end
end
