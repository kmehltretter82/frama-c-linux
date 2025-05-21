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

type t = {
  read : Locations.Zone.t;
  written : Locations.Zone.t;
}

module Access = struct
  include Datatype.Make(struct
      type nonrec t = t
      let name = "Eva.Variables.Access"
      let reprs =
        List.fold_left
          (fun acc read ->
             List.fold_left
               (fun acc written ->
                  { read ; written } :: acc)
               acc
               Locations.Zone.reprs)
          []
          Locations.Zone.reprs
      include Datatype.Serializable_undefined
    end)
  let bottom = { read = Locations.Zone.bottom; written = Locations.Zone.bottom }

  let is_bottom access =
    Locations.Zone.is_bottom access.read &&
    Locations.Zone.is_bottom access.written

  let add_read zone access =
    { access with read = Locations.Zone.join access.read zone }

  let add_write zone access =
    { access with written = Locations.Zone.join access.written zone }
end

let pretty_debug fmt access =
  Format.fprintf fmt "@[{ read: %a;@ written: %a; }@]"
    Locations.Zone.pretty access.read
    Locations.Zone.pretty access.written

module Cache : sig
  (** Get read/written memory zones for an analysis location. *)
  val get : Analysis_location.t -> t

  (** Change read/written memory zones for an analysis location. I.e. get the
      value, apply the given function then set the result. *)
  val change : Analysis_location.t -> (t -> t) -> unit

  (** Fold over all analysis locations and their read/written memory zones. *)
  val fold : (Analysis_location.t -> t -> 'acc -> 'acc) -> 'acc -> 'acc

  (** Dump the internal state regarding the read/written memory zones. Before
      dumping the memory zones are [filter]ed. *)
  val dump : filter:(t -> t) -> Format.formatter -> unit
end = struct
  (** State representing the read and written memory zones per analysis
      location. *)
  module State =
    State_builder.Hashtbl
      (Analysis_location.Hashtbl)
      (Access)
      (struct
        let name = "Eva.Inout_access.Cache.State"
        let size = 11
        let dependencies = [ Self.state ]
      end)

  let get (aloc : Analysis_location.t) =
    try State.find aloc
    with Not_found -> Access.bottom

  let change aloc f =
    State.replace aloc (f (get aloc))

  let fold = State.fold

  let dump ~filter fmt =
    State.iter
      (fun aloc access ->
         let access = filter access in
         if not @@ Access.is_bottom access then
           Format.fprintf fmt ">>> %a: %a"
             Analysis_location.pretty aloc
             pretty_debug access)
end

let add_read aloc zone =
  Cache.change aloc (Access.add_read zone)

let add_write aloc zone =
  Cache.change aloc (Access.add_write zone)

let mk_filter ~filter_base =
  let filter_zone = Locations.Zone.filter_base filter_base in
  (fun access ->
     { read = filter_zone access.read;
       written = filter_zone access.written })
let keep_globals_only = mk_filter ~filter_base:Base.is_global

let at ?(filter=Fun.id) aloc = Cache.get aloc |> filter

let fold ?(filter=Fun.id) f init_acc =
  Cache.fold
    (fun aloc access acc ->
       let access = filter access in
       if not (Access.is_bottom access) then
         f aloc access acc
       else
         acc)
    init_acc

let iter ?(filter=Fun.id) f =
  fold ~filter
    (fun aloc access () -> f aloc access)
    ()

let dump ?(filter=Fun.id) fmt =
  Format.fprintf fmt "@.###### START OF DUMP OF VARIABLES #######@.";
  Cache.dump ~filter fmt;
  Format.fprintf fmt "@.####### END OF DUMP OF VARIABLES ########@.";
  ()
