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

type value = Value.t


module Mutex =
struct
  include Mutex
  let name = "MtThread.Mutex"
  let key_name = "mutex"
  let of_value x =
    let open Result in
    let* l = Value.to_int_list x in
    let convert_one acc id =
      let* acc = acc in
      match find id with
      | None -> Result.error "Not a valid mutex id '%d'." id
      | Some th -> Result.ok (th :: acc)
    in
    List.fold_left convert_one (Result.ok []) l
  let to_value th = Value.of_int (id th)
end


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
  include MtRegister.Make (Mutex) (Status)
  let check bad msg st =
    if Status.equal bad st then MtRegister.Invalid (msg, true) else Ok
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
