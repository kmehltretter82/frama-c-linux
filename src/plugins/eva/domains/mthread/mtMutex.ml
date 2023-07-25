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

open MtUtils



type name = Name.t
type value = Value.t

module Mutex = struct
  type mutex' = { name : name }
  let dummy_unhashconsed = { name = Name.of_string "dummy" }

  module Mutex' = Datatype.Make_with_collections (struct
      include Datatype.Serializable_undefined
      type t = mutex'
      let name = "Mthread.mutex"
      let reprs = [ dummy_unhashconsed ]
      let compare x y = Name.compare x.name y.name
      let equal x y = compare x y = 0
      let hash x = Name.hash x.name
      let pretty fmt { name } = Name.pretty fmt name
    end)

  module MutexInfos = struct
    let name = "Mthread.mutex.hashconsed"
    let dependencies = []
    let initial_values = []
  end

  include State_builder.Hashcons (Mutex') (MutexInfos)
  let key_name = "mutex"
  let key_id mutex = id mutex + 1 |> Z.of_int |> Value.inject_int
  let pretty_msg fmt t = get t |> fun { name } -> Name.pretty fmt name
end

type mutex = Mutex.t
include Mutex


let id = Mutex.key_id

let hashcons, of_cvalue =
  let module Cache = Datatype.Int.Hashtbl in
  let cache : mutex Cache.t = Cache.create 10 in
  let hashcons mutex =
    let hashconsed = Mutex.hashcons mutex in
    let id = Mutex.id hashconsed + 1 in
    Cache.add cache id hashconsed ;
    hashconsed
  and of_cvalue cvalue =
    match Value.extract_singleton cvalue with
    | None -> Result.error "Not a singleton value."
    | Some id ->
      match Cache.find_opt cache id with
      | None -> Result.error "%d is not a valid mutex id." id
      | Some mutex -> Result.ok mutex
  in
  hashcons, of_cvalue

let create name = hashcons { name }
let to_cvalue mutex = Mutex.id mutex |> Z.of_int |> Value.inject_int



type status = Locked | Unlocked
module Status = struct
  include Datatype.Make (struct
      include Datatype.Serializable_undefined
      type t = status
      let name = "Mthread.mutex.status"
      let reprs = [ Locked ; Unlocked ]
      let hash = function Locked -> 0 | Unlocked -> 1
      let compare x y = Datatype.Int.compare (hash x) (hash y)
      let equal x y = compare x y = 0
      let to_string = function Locked -> "locked" | Unlocked -> "unlocked"
      let pretty fmt status = Format.fprintf fmt "%s" (to_string status)
    end)

  (* There is a total order on statuses, that can be used as a partial order as
     it encodes the idea that we want to keep mutexes unlocked if we are not
     sure of their status. *)
  let is_included x y = compare x y <= 0
  let join x y = if compare x y <= 0 then y else x
  let default = Unlocked
end

module MSet = Set


(* A register of all the program's mutexes and their current status. A mutex is
   registered as locked if and only if we are absolutly sure that it is locked.
   It is indeed necessary to ensure soundness, as it will trigger more
   interferences as necessary. *)
module Register = struct
  include Register (Mutex) (Status)
  let check bad msg st = if Status.equal bad st then Invalid (msg, true) else Ok
  let lock = update (fun _ -> Locked) (check Locked "locked")
  let unlock = update (fun _ -> Unlocked) (check Unlocked "unlocked")

  let locked_mutexes register =
    let add mutex status acc =
      match status with
      | Locked -> Mutex.Set.add mutex acc
      | Unlocked -> acc
    in
    fold add register Mutex.Set.empty
end
