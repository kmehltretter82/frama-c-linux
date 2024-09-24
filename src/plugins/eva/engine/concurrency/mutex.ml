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

(* --- Mutex definition --- *)

module Prototype =
struct
  include Datatype.Serializable_undefined

  type t = {
    id: int;
    name: Concurency.Name.t option
  }

  let name = "Mutex"
  let reprs = [{ id = 0; name = None }]
  let equal m1 m2 = Int.equal m1.id m2.id
  let compare m1 m2 = Int.compare m1.id m2.id
  let hash m = m.id

  let pretty fmt m =
    match m.name with
    | Some name ->
      Concurency.Name.pretty fmt name
    | None ->
      Format.fprintf fmt "#%i" m.id
end

module Mutex = Datatype.Make_with_collections (Prototype)
include Prototype
include Mutex

let id m = m.id
let label m = Pretty_utils.to_string pretty m


(* --- Mutex registering --- *)

module MutexesById = State_builder.Hashtbl (Datatype.Int.Hashtbl) (Mutex)
    (struct
      let name = "Mutex.MutexesById"
      let dependencies = []
      let size = 13
    end)

let last_mutex_id = ref 0

let create name =
  incr last_mutex_id;
  let m = { id = !last_mutex_id; name } in
  MutexesById.add m.id m;
  m

let find id =
  MutexesById.find_opt id


(* --- Mutex identity --- *)

(* The identity of a mutex is used to choose how to group mutex creations
   during the analysis. This is especially useful if the mutex is created inside
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

    let name = "Mutex.Identity"

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

module Identities = State_builder.Hashtbl (Identity.Hashtbl) (Mutex)
    (struct
      let name = "Mutex.Identities"
      let dependencies = []
      let size = 13
    end)


(* Mutexes state *)

let create creation_point name =
  let identity = match name with
    | Some name -> Identity.Prototype.ByName name
    | None -> ByCreationPoint creation_point
  in
  Identities.memo (fun _ -> create name) identity

let reset_state () =
  last_mutex_id := 0;
  MutexesById.clear ();
  Identities.clear ()
