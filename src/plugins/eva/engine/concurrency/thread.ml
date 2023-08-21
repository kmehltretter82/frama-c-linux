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

(* --- Threads definition --- *)

module Prototype =
struct
  include Datatype.Serializable_undefined

  (* This type only defines immutable properties of threads and is enough
     to print a human-readable description of the thread. *)
  type t = {
    id: int;
    name: Concurency.Name.t option
  }

  let name = "Thread"
  let main = { id = 1; name = None } (* The main thread always is the thread 0 *)
  let reprs = [main]
  let equal th1 th2 = Int.equal th1.id th2.id
  let compare th1 th2 = Int.compare th1.id th2.id
  let hash th = th.id

  let pretty fmt th =
    match th.name with
    | Some name ->
      Concurency.Name.pretty fmt name
    | None when th == main ->
      Format.fprintf fmt "<main>"
    | None ->
      Format.fprintf fmt "#%i" th.id
end

module Thread = Datatype.Make_with_collections (Prototype)
include Prototype
include Thread

let is_main = equal main
let id th = th.id
let label th = Pretty_utils.to_string pretty th


(* --- Threads registering --- *)

module ThreadsById = State_builder.Hashtbl (Datatype.Int.Hashtbl) (Thread)
    (struct
      let name = "Thread.ThreadsById"
      let dependencies = []
      let size = 13
    end)

let last_thread_id = ref 1

let create name =
  incr last_thread_id;
  let th = { id = !last_thread_id; name } in
  ThreadsById.add th.id th;
  th

let find id =
  ThreadsById.find_opt id


(* --- Current Thread --- *)

let current, set_current =
  let r = ref main in
  (fun () -> !r), (fun id -> r := id)


(* --- Thread identity --- *)

(* The identity of a thread is used to choose whether to group thread
   analyses or not. If two spawned threads share the same identity, they
   will be handled in the same analysis. *)

module Identity =
struct
  module Key =
  struct
    type t =
      | ByName of Concurency.Name.t
      | BySpawnPoint of Analysis_location.Local.t
    [@@deriving eq, ord]

    let reprs =
      List.map (fun n -> ByName n) Concurency.Name.reprs @
      List.map (fun al -> BySpawnPoint al) Analysis_location.Local.reprs

    let hash = function
      | ByName name ->
        Stdlib.Hashtbl.hash(1, Concurency.Name.hash name)
      | BySpawnPoint al ->
        Stdlib.Hashtbl.hash(2, Analysis_location.Local.hash al)
  end

  module Prototype =
  struct
    include Datatype.Serializable_undefined

    type t = {
      key: Key.t;
      entry_point: Kernel_function.t;
    }
    [@@deriving eq, ord]

    let name = "Thread.Identity"
    let reprs =
      List.concat_map
        (fun k -> List.map
            (fun kf -> { key = k ; entry_point = kf })
            Kernel_function.reprs)
        Key.reprs
    let hash identity =
      let { key ; entry_point } = identity in
      Stdlib.Hashtbl.hash (Key.hash key, Kernel_function.hash entry_point)
  end

  include Prototype
  include Datatype.Make_with_collections (Prototype)
end

module Identities = State_builder.Hashtbl (Identity.Hashtbl) (Thread)
    (struct
      let name = "Thread.Identities"
      let dependencies = []
      let size = 13
    end)


(* --- Thread state --- *)

(* The thread state is all the information learned about the threads during
   the analysis *)

module ALSet = Analysis_location.Local.Set

module Properties =
struct
  module Prototype =
  struct
    open Cil_datatype

    include Datatype.Serializable_undefined

    type t = {
      entry_point : Kernel_function.t;
      spawn_points : ALSet.t;
      arguments : (Varinfo.t * Cvalue.V.t) list;
    }

    let name = "Thread.Properties"
    let reprs = [{
        entry_point = List.hd Kernel_function.reprs;
        spawn_points = List.hd ALSet.reprs;
        arguments = [List.hd Varinfo.reprs, List.hd Cvalue.V.reprs];
      }]
    let pretty fmt properties =
      let spawn_points = ALSet.elements properties.spawn_points in
      let pp_sep fmt () = Format.fprintf fmt ";@ " in
      let pp_var = Varinfo.pretty in
      let pp_val = Cvalue.V.pretty in
      let pp_al = Analysis_location.Local.pretty in
      let pp_arg fmt (vi, v) = Format.fprintf fmt "%a: %a" pp_var vi pp_val v in
      Format.fprintf fmt
        "@[<v 2>Entry point  :@ @[<hov>%a@]@]@\n\
         @[<v 2>Spawn points :@ @[<hov>%a@]@]@\n\
         @[<v 2>Arguments    :@ @[<hov>%a@]@]"
        Kernel_function.pretty properties.entry_point
        Format.(pp_print_list ~pp_sep pp_al) spawn_points
        Format.(pp_print_list ~pp_sep pp_arg) properties.arguments
  end

  include Prototype
  include Datatype.Make (Prototype)

  (* Combine a list of arguments with their formal parameters; used
     for arguments value storage *)
  let map_arguments kf args =
    let formals = Kernel_function.get_formals kf in
    try
      List.combine formals args
    with Invalid_argument _ ->
      Self.abort
        "Arguments mismatch in thread creation; function %s expected %d \
         arguments, but %d were given"
        (Kernel_function.get_name kf) (List.length formals) (List.length args)

  let create spawn_point entry_point arguments =
    {
      entry_point;
      spawn_points = ALSet.singleton spawn_point;
      arguments = map_arguments entry_point arguments
    }

  let main_properties () =
    {
      entry_point = Globals.entry_point () |> fst;
      spawn_points = ALSet.empty;
      arguments = [];
    }

  let add properties spawn_point entry_point arguments =
    assert (Kernel_function.equal entry_point properties.entry_point);
    {
      entry_point;
      spawn_points = ALSet.add spawn_point properties.spawn_points;
      arguments =
        (* Join a thread argument as varinfo * cvalue with a new cvalue *)
        let join_argument (vi, v1) v2 = (vi, Cvalue.V.join v1 v2) in
        try List.map2 join_argument properties.arguments arguments
        with Invalid_argument _ ->
          Self.abort ~current:true
            "Trying to spawn a thread with %d arguments when it was \
             already spawned with %d"
            (List.length arguments)
            (List.length properties.arguments)
    }

end

module State = State_builder.Hashtbl (Hashtbl) (Properties)
    (struct
      let name = "Thread.State"
      let dependencies = []
      let size = 13
    end)


let spawn_single_entry_point spawn_point name entry_point arguments =
  let key = match name with
    | Some name -> Identity.Key.ByName name
    | None -> BySpawnPoint spawn_point
  in
  let identity = Identity.Prototype.{ key; entry_point } in
  let th = Identities.memo (fun _ -> create name) identity in
  let properties = match State.find_opt th with
    (* Thre thread identity is new; register this thread *)
    | None ->
      Properties.create spawn_point entry_point arguments
    (* The thread identity has been found; join the thread properties *)
    | Some properties ->
      Properties.add properties spawn_point entry_point arguments
  in
  State.replace th properties;
  th

let spawn spawn_point name entry_points arguments =
  List.map
    (fun kf -> spawn_single_entry_point spawn_point name kf arguments)
    entry_points

let reset_state () =
  last_thread_id := 1;
  ThreadsById.clear ();
  State.clear ();
  ThreadsById.add main.id main;
  State.add main (Properties.main_properties ());
  set_current main

let get_properties = State.find

let entry_point th =
  (get_properties th).entry_point
