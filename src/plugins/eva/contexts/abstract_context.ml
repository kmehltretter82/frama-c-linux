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

(** An abstract context can be used to transfer information from the state of
    an abstract domain, in which an expression or lvalue is evaluated, to a
    value abstraction, which interprets operations during this evaluation.
    The context is built by the function [build_context] of abstract domains,
    and passed as argument of most transfer functions from {!Abstract_value}. *)

open Eval

module type S = sig
  type t

  (** The default context used in a top abstract state, or if no domain has been
      enabled — or no domain providing this context. *)
  val top : t

  (** In a product of abstract domains, merges the context provided by the
      abstract state of each domain. *)
  val narrow : t -> t -> t or_bottom
end

(** Keys used to identify context modules. *)
type 'c key = 'c Structure.Key_Context.key

(** Signature for a leaf module of context. *)
module type Leaf = sig
  include S

  (** The key identifies the module and the type [t] of context. *)
  val key : t key
end

(** Eva abstractions are divided between contexts, values, locations and domains.
    Values and domains depend on contexts, and use this type to declare such
    dependencies. In the standard case, a value or domain depends on a single
    context module [Ctx] and uses [Leaf (module Ctx)] to declare this dependency. *)
type 'c dependencies =
  | Leaf : (module Leaf with type t = 'c) -> 'c dependencies
  | Node : 'l dependencies * 'r dependencies -> ('l * 'r) dependencies
