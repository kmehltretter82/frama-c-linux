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

(* Helpers signature *)
module type Helpers = sig
  type 'a t

  module Bool : sig
    val only_if : bool -> unit t -> unit t
  end

  module Option : sig
    val iter : ('a -> unit t) -> 'a option -> unit t
    val map : ('a -> 'b t) -> 'a option -> 'b option t
  end

  module List : sig
    val iter : ('a -> unit t) -> 'a list -> unit t
    val map : ('a -> 'b t) -> 'a list -> 'b list t
    val fold_left : ('a -> 'b -> 'a t) -> 'a -> 'b list -> 'a t
  end

end

(* Basic signature with all monadic functions *)
module type Basic = sig
  type 'a t
  val return : 'a -> 'a t
  val flatten : 'a t t -> 'a t
  val map  : ('a -> 'b  ) -> 'a t -> 'b t
  val bind : ('a -> 'b t) -> 'a t -> 'b t
end

(* Complete signature *)
module type S = sig
  include Basic
  include Helpers with type 'a t := 'a t
  module Operators : sig
    val ( >>-  ) : 'a t -> ('a -> 'b t) -> 'b t
    val ( let* ) : 'a t -> ('a -> 'b t) -> 'b t
    val ( >>-: ) : 'a t -> ('a -> 'b) -> 'b t
    val ( let+ ) : 'a t -> ('a -> 'b) -> 'b t
  end
end

(* Complete signature with a product *)
module type S_with_product = sig
  include Basic
  val product : 'a t -> 'b t -> ('a * 'b) t
  include Helpers with type 'a t := 'a t
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


(* Basic based on bind signature *)
module Basic_based_on_bind (M : Based_on_bind) = struct
  type 'a t = 'a M.t
  let return x = M.return x
  let bind f m = M.bind f m
  let flatten m = bind (fun x -> x) m
  let map f m = bind (fun x -> return (f x)) m
end

(* Basic based on map signature *)
module Basic_based_on_map (M : Based_on_map) = struct
  type 'a t = 'a M.t
  let return x = M.return x
  let map f m = M.map f m
  let flatten m = M.flatten m
  let bind f m = flatten (map f m)
end

(* Make operators from extended signatures *)
module Make_operators (M : Basic) = struct
  let ( >>-  ) m f = M.bind f m
  let ( let* ) m f = M.bind f m
  let ( >>-: ) m f = M.map  f m
  let ( let+ ) m f = M.map  f m
end

module Make_bool (M : Basic) = struct
  let only_if b m = if b then m else M.return ()
end

module Make_option (M : Basic) = struct

  let iter f = function
    | None -> M.return ()
    | Some x -> f x

  let map f = function
    | None -> M.return None
    | Some x -> M.map (fun x -> Some x) (f x)

end

module Make_list (M : Basic) = struct

  let fold_left f acc xs =
    let f acc x = M.bind (fun acc -> f acc x) acc in
    Stdlib.List.fold_left f (M.return acc) xs

  let iter f xs =
    fold_left (fun () -> f) () xs

  let map f xs =
    let f rs x = M.map (fun r -> r :: rs) (f x) in
    M.map Stdlib.List.rev (fold_left f [] xs)

end


(* Extend a basic monad based on bind minimal monad *)
module Make_based_on_bind (M : Based_on_bind) = struct
  module Basic = Basic_based_on_bind (M)
  module Operators = Make_operators (Basic)
  module Bool = Make_bool (Basic)
  module Option = Make_option (Basic)
  module List = Make_list (Basic)
  include Basic
end

(* Extend a basic monad based on map minimal monad *)
module Make_based_on_map (M : Based_on_map) = struct
  module Basic = Basic_based_on_map (M)
  module Operators = Make_operators (Basic)
  module Bool = Make_bool (Basic)
  module Option = Make_option (Basic)
  module List = Make_list (Basic)
  include Basic
end

(* Extend a basic monad based on bind monad with a product *)
module Make_based_on_bind_with_product (M : Based_on_bind_with_product) = struct
  include Make_based_on_bind (M)
  let product = M.product
  module Operators = struct
    include Operators
    let ( and* ) l r = product l r
    let ( and+ ) l r = product l r
  end
end

(* Extend a basic monad based on map monad with a product *)
module Make_based_on_map_with_product (M : Based_on_map_with_product) = struct
  include Make_based_on_map (M)
  let product = M.product
  module Operators = struct
    include Operators
    let ( and* ) l r = product l r
    let ( and+ ) l r = product l r
  end
end
