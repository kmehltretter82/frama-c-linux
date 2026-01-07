(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Mt_utils


type update_check = Ok | Invalid of (string * bool)

module type Key_sig = sig
  include Hptmap.Id_Datatype
  val key_name : string
  val of_value : Value.t -> t list Result.t
  val to_value : t -> Value.t
end

module type Status_sig = sig
  include Lattice_type.Join_Semi_Lattice
  val default : t
end

module Make (Key : Key_sig) (Status : Status_sig) : sig
  include Datatype.S_with_collections
  type status = Status.t
  type key = Key.t

  val empty : t
  val id : t -> int

  val mem : key -> t -> bool
  val find : key -> t -> status option
  val add : key -> status -> t -> t

  val register : key list -> t -> (t * Value.t) Result.t
  val update : (status -> status) -> (status -> update_check) ->
    Value.t -> t -> (t * Value.t) Result.t

  val top : t
  val is_included : t -> t -> bool
  val narrow : t -> t -> t
  val join : t -> t -> t

  val fold : (key -> status -> 'a -> 'a) -> t -> 'a -> 'a
end
