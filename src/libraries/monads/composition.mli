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

module type Axiom = sig
  type 'a interior and 'a exterior
  val swap : 'a exterior interior -> 'a interior exterior
end

module Make
    (Int : Monad.S)
    (Ext : Monad.S)
    (_ : Axiom with type 'a interior = 'a Int.t and type 'a exterior = 'a Ext.t)
  : Monad.S with type 'a t = 'a Int.t Ext.t

module Make_with_product
    (Int : Monad.S_with_product)
    (Ext : Monad.S_with_product)
    (_ : Axiom with type 'a interior = 'a Int.t and type 'a exterior = 'a Ext.t)
  : Monad.S_with_product with type 'a t = 'a Int.t Ext.t
