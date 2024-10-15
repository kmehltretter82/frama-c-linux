(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2024                                               *)
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



(* Kleisli triple minimal signature *)
module type Kleisli = sig
  type 'a t
  val return : 'a -> 'a t
  val bind : ('a -> 'b t) -> 'a t -> 'b t
end

(* Categoric minimal signature *)
module type Categoric = sig
  type 'a t
  val return : 'a -> 'a t
  val map : ('a -> 'b) -> 'a t -> 'b t
  val flatten : 'a t t -> 'a t
end

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

(** Extend a Kleisli triple monad *)
module Extend_Kleisli (M : Kleisli) = struct
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

(** Extend a categoric monad *)
module Extend_Categoric (M : Categoric) = struct
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



(* Product on monads *)
module type Product = sig
  type 'a t
  val product : 'a t -> 'b t -> ('a * 'b) t
end

(* Kleisli triple with a product *)
module type Kleisli_with_product = sig
  include Kleisli
  include Product with type 'a t := 'a t
end

(* Categoric monad with a product *)
module type Categoric_with_product = sig
  include Categoric
  include Product with type 'a t := 'a t
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

(** Extend a Kleisli triple monad with a product *)
module Extend_Kleisli_with_product (M : Kleisli_with_product) = struct
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

(** Extend a categoric monad with a product *)
module Extend_Categoric_with_product (M : Categoric_with_product) = struct
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
