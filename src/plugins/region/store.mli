(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

module type Element = sig
  type 'a t
  val default_id : int
  val get_id : 'a t -> int
  val set_id : 'a t -> int -> unit
end

module Make (E:Element) : sig
  type 'a t

  type 'a store
  val new_store : unit -> 'a store
  val copy : 'a store -> 'a store

  val key : 'a t -> int
  val id : 'a t -> int
  val forge_id : 'a store ref -> int -> 'a t
  val forge_key : 'a store ref -> int -> 'a t
  val get_map : 'a t -> 'a store ref
  val set_map : 'a store ref -> 'a t -> unit

  val new_value : 'a store ref -> 'a E.t -> 'a t
  val get : 'a t -> 'a E.t
  val set : 'a t -> 'a E.t -> unit
  val set_id : 'a t -> int -> unit
  val normalize : ?store:'a store ref -> 'a t -> 'a t

  val eq : 'a t -> 'a t -> bool
  val min : 'a t -> 'a t -> 'a t
  val list : 'a t list -> 'a t list
  val bag : 'a list -> 'a list -> 'a list
  val union : 'a t -> 'a t -> 'a t

  val pp_all : Format.formatter -> 'a store ref -> unit
end
