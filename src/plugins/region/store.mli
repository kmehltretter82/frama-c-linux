(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

module type Element = sig
  type 'a t
  val get_id : 'a t -> int
  val set_id : 'a t -> int -> 'a t
end

module Make (E:Element) : sig
  type 'a t

  type 'a store
  val new_store : unit -> 'a store
  val copy : 'a store -> 'a store

  val key : 'a t -> int
  val id : 'a t -> int
  val forge : 'a store -> int -> 'a t
  val get_map : 'a t -> 'a store

  val new_value : 'a store -> 'a E.t -> 'a t
  val get : 'a t -> 'a E.t
  val set : 'a t -> 'a E.t -> unit
  val set_id : 'a t -> int -> unit
  val normalize : 'a t -> 'a t

  val eq : 'a t -> 'a t -> bool
  val list : 'a t list -> 'a t list
  val bag : 'a list -> 'a list -> 'a list
  val union : 'a t -> 'a t -> 'a t
end
