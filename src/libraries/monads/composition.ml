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

module type Axiom = sig
  type 'a interior and 'a exterior
  val swap : 'a exterior interior -> 'a interior exterior
end

(* Using [Based_on_map] here, as the natural way to write the [bind] is through
   [map] and [flatten]. *)
module Make
    (Int : Monad.S)
    (Ext : Monad.S)
    (X : Axiom with type 'a interior = 'a Int.t and type 'a exterior = 'a Ext.t)
  = Monad.Make_based_on_map (struct
    type 'a t = 'a Int.t Ext.t
    let return  x = Ext.return (Int.return x)
    let map   f m = Ext.map (Int.map f) m
    let flatten m = Ext.map X.swap m |> Ext.flatten |> Ext.map Int.flatten
  end)

(* As for the previous functor and for the exact same reason, we use
   [Based_on_map_with_product]. *)
module Make_with_product
    (Int : Monad.S_with_product) (Ext : Monad.S_with_product)
    (X : Axiom with type 'a interior = 'a Int.t and type 'a exterior = 'a Ext.t)
  = Monad.Make_based_on_map_with_product (struct
    type 'a t = 'a Int.t Ext.t
    let return  x = Ext.return (Int.return x)
    let map   f m = Ext.map (Int.map f) m
    let flatten m = Ext.map X.swap m |> Ext.flatten |> Ext.map Int.flatten
    let product l r = Ext.product l r |> Ext.map (fun (l, r) -> Int.product l r)
  end)
