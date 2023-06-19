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

type id_type = IdThread | IdMutex | IdQueue

module IdType :
sig
  include Datatype.S with type t = id_type

  val format_lc : t -> ('a, 'b, 'c, 'd, 'd, 'a) format6
  val pretty_lc : Format.formatter -> t -> unit
  val pretty_lc_plural : Format.formatter -> id_type -> unit
end

type raw_id = id_type * int

module RawId :
  Datatype.S_with_collections
  with type t = IdType.t * Datatype.Int.t

module MapCreation : Map.S with type key = RawId.t * Eva.Callstack.t

type id_name_hint =
    Hint_pointer of MtMemory.Types.pointer
  | Hint_string of string
  | NoHint

module IdNameHint : Datatype.S_with_collections
  with type t = id_name_hint

type id = {
  id_raw : raw_id;
  id_creator : id;
  mutable id_updated : int;
  mutable id_name : string;
  mutable id_name_hint : id_name_hint;
}
val raw_id_main_thread : id_type * int
val id_main_thread : id
module Id :
sig
  include Datatype.S_with_collections
    with type t = id
  type set = Set.t
  type 'a map = 'a Map.t
  val compare_by_name : t -> t -> int
  val id_type : id -> id_type
  val sanitize_name : ?char:char -> t -> string
end

type known_ids = {
  ids_infos : id RawId.Map.t;
  ids_by_names : raw_id IdNameHint.Map.t;
  ids_by_stacks : raw_id MapCreation.t;
  next_thread_id : int;
  next_mutex_id : int;
  next_queue_id : int;
}
val no_known_ids : known_ids
val find_id :
  known_ids ->
  raw_id -> [> `Failure of Format.formatter -> unit | `Success of id ]
val all_ids_by_idtype : IdType.t -> known_ids -> Id.Set.t
val all_threads : known_ids -> Id.Set.t
val all_mutexes : known_ids -> Id.Set.t
val all_queues : known_ids -> Id.Set.t
val array_threads : unit -> Cil_types.varinfo
val array_mutexes : unit -> Cil_types.varinfo
val array_queues : unit -> Cil_types.varinfo
val array_of_idt : id_type -> Cil_types.varinfo
val array_size : Cil_types.varinfo -> int
val next_id_ok : IdType.t -> int -> unit
val register_new_id_aux :
  known_ids ->
  IdType.t ->
  IdNameHint.Map.key ->
  Eva.Callstack.t ->
  Id.t ->
  int ->
  [> `Failure of Format.formatter -> unit
  | `Success of id * known_ids
  | `WithWarning of (Format.formatter -> unit) * (id * known_ids) ]
val register_new_id :
  known_ids ->
  IdType.t ->
  IdNameHint.Map.key ->
  Eva.Callstack.t ->
  Id.t ->
  int ->
  [> `Failure of Format.formatter -> unit
  | `Success of id * known_ids
  | `WithWarning of (Format.formatter -> unit) * (id * known_ids) ]
val give_name_to_id :
  known_ids ->
  id ->
  IdNameHint.Map.key ->
  [> `Failure of Format.formatter -> unit
  | `Success of string option * known_ids ]
val pointer_of_id : raw_id -> MtMemory.Types.pointer
exception NoNiceName
val nice_offset : Cil_types.typ -> int -> string -> string
val extract_name_hint : Cvalue.V.t -> id_name_hint MtLib.conversion
val read_id_state : MtMemory.Types.state -> id -> MtMemory.Types.value
val read_id_state_enumerate :
  int -> MtMemory.Types.state -> Id.t -> int list MtLib.conversion
val write_id_state :
  MtMemory.Types.state -> id -> int -> MtMemory.Types.state
val replace_id_value :
  MtMemory.Types.state ->
  id -> before:int -> after:int -> MtMemory.Types.state
val id_offset : id -> int
