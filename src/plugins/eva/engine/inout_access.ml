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

module Prototype = struct
  type t = {
    read : Locations.Zone.t;
    write : Locations.Zone.t;
  }
  [@@deriving eq,ord]
end
include Prototype

module Access = struct
  include Datatype.Make(struct
      include Datatype.Serializable_undefined
      include Prototype
      let name = "Eva.Inout_access.Access"
      let reprs =
        List.fold_left
          (fun acc read ->
             List.fold_left
               (fun acc write ->
                  { read ; write } :: acc)
               acc
               Locations.Zone.reprs)
          []
          Locations.Zone.reprs
      let pretty fmt access =
        Format.fprintf fmt "@[{ read: %a;@ write: %a; }@]"
          Locations.Zone.pretty access.read
          Locations.Zone.pretty access.write
    end)
  let bottom = { read = Locations.Zone.bottom; write = Locations.Zone.bottom }

  let is_bottom access =
    Locations.Zone.is_bottom access.read &&
    Locations.Zone.is_bottom access.write

  let is_included l r =
    Locations.Zone.is_included l.read r.read
    && Locations.Zone.is_included l.write r.write

  let join l r =
    { read = Locations.Zone.join l.read r.read;
      write = Locations.Zone.join l.write r.write }

  let make ?read ?write () =
    let default = Locations.Zone.bottom in
    { read = Option.value ~default read;
      write = Option.value ~default write; }

  let add_read zone access =
    { access with read = Locations.Zone.join access.read zone }

  let add_write zone access =
    { access with write = Locations.Zone.join access.write zone }
end

module Cache : sig
  (** Get read/written memory zones for an analysis location. *)
  val get : Position.t -> t

  (** Change read/written memory zones for an analysis location. I.e. get the
      value, apply the given function then set the result. *)
  val change : Position.t -> (t -> t) -> unit

  (** Fold over all analysis locations and their read/written memory zones. *)
  val fold : (Position.t -> t -> 'acc -> 'acc) -> 'acc -> 'acc

  (** Dump the internal state regarding the read/written memory zones. Before
      dumping the memory zones are [filter]ed. *)
  val dump : filter:(t -> t) -> Format.formatter -> unit
end = struct
  (** State representing the read and written memory zones per analysis
      location. *)
  module State =
    State_builder.Hashtbl
      (Position.Hashtbl)
      (Access)
      (struct
        let name = "Eva.Inout_access.Cache.State"
        let size = 11
        let dependencies = [ Self.state ]
      end)

  let get (pos : Position.t) =
    try State.find pos
    with Not_found -> Access.bottom

  let change pos f =
    State.replace pos (f (get pos))

  let fold = State.fold

  let dump ~filter fmt =
    State.iter
      (fun pos access ->
         let access = filter access in
         if not @@ Access.is_bottom access then
           Format.fprintf fmt ">>> %a: %a"
             Position.pretty pos
             Access.pretty access)
end

let register_read pos zone =
  Cache.change pos (Access.add_read zone)

let register_write pos zone =
  Cache.change pos (Access.add_write zone)

let register pos access =
  Cache.change pos (Access.join access)

let mk_filter ~filter_base =
  let filter_zone = Locations.Zone.filter_base filter_base in
  (fun access ->
     { read = filter_zone access.read;
       write = filter_zone access.write })
let keep_globals_only = mk_filter ~filter_base:Base.is_global

let at ?(filter=Fun.id) pos = Cache.get pos |> filter

let fold ?(filter=Fun.id) f init_acc =
  Cache.fold
    (fun pos access acc ->
       let access = filter access in
       if not (Access.is_bottom access) then
         f pos access acc
       else
         acc)
    init_acc

let iter ?(filter=Fun.id) f =
  fold ~filter
    (fun pos access () -> f pos access)
    ()

let dump ?(filter=Fun.id) fmt =
  Format.fprintf fmt "@.###### START OF DUMP OF VARIABLES #######@.";
  Cache.dump ~filter fmt;
  Format.fprintf fmt "@.####### END OF DUMP OF VARIABLES ########@.";
  ()
