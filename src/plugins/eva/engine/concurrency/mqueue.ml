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

(* --- Mqueues definition --- *)

module Prototype =
struct
  include Datatype.Serializable_undefined

  type t = {
    id: int;
    name: Concurency.Name.t option
  }

  let name = "Queue"
  let reprs = [{ id = 0; name = None }]
  let equal q1 q2 = Int.equal q1.id q2.id
  let compare q1 q2 = Int.compare q1.id q2.id
  let hash q = q.id

  let pretty fmt q =
    match q.name with
    | Some name ->
      Concurency.Name.pretty fmt name
    | None ->
      Format.fprintf fmt "#%i" q.id
end

module Queue = Datatype.Make_with_collections (Prototype)
include Prototype
include Queue

let id q = q.id
let label q = Pretty_utils.to_string pretty q


(* --- Queue registering --- *)

module MqueuesById = State_builder.Hashtbl (Datatype.Int.Hashtbl) (Queue)
    (struct
      let name = "Queue.MqueuesById"
      let dependencies = []
      let size = 13
    end)

let last_queue_id = ref 0

let create name =
  incr last_queue_id;
  let q = { id = !last_queue_id; name } in
  MqueuesById.add q.id q;
  q

let find id =
  MqueuesById.find_opt id


(* --- Queue identity --- *)

(* The identity of a queue is used to choose how to group mqueues creations
   during the analysis. This is especially useful if the queue is created inside
   a - potentially not unrollled - loop. *)

module Identity =
struct
  module Prototype =
  struct
    include Datatype.Serializable_undefined

    type t =
      | ByName of Concurency.Name.t
      | ByCreationPoint of Analysis_location.Local.t
    [@@deriving eq, ord]

    let name = "Queue.Identity"

    let reprs =
      List.map (fun n -> ByName n) Concurency.Name.reprs @
      List.map (fun al -> ByCreationPoint al) Analysis_location.Local.reprs

    let hash = function
      | ByName name ->
        Stdlib.Hashtbl.hash(1, Concurency.Name.hash name)
      | ByCreationPoint al ->
        Stdlib.Hashtbl.hash(2, Analysis_location.Local.hash al)
  end

  include Prototype
  include Datatype.Make_with_collections (Prototype)
end

module Identities = State_builder.Hashtbl (Identity.Hashtbl) (Queue)
    (struct
      let name = "Queue.Identities"
      let dependencies = []
      let size = 13
    end)


(* Mqueues state *)

let create creation_point name =
  let identity = match name with
    | Some name -> Identity.Prototype.ByName name
    | None -> ByCreationPoint creation_point
  in
  Identities.memo (fun _ -> create name) identity

let reset_state () =
  last_queue_id := 0;
  MqueuesById.clear ()
