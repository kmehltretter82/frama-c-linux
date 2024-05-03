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

module Zone = Locations.Zone

type deps = {
  data: Zone.t;
  indirect: Zone.t;
}

(* Pretty printing of detailed internal representation *)
let pretty_precise fmt {data; indirect} =
  let bottom_data = Zone.is_bottom data in
  let bottom_indirect = Zone.is_bottom indirect in
  match bottom_indirect, bottom_data with
  | true, true ->
    Format.fprintf fmt "\\nothing"
  | true, false ->
    Format.fprintf fmt "direct: %a"
      Zone.pretty data
  | false, true ->
    Format.fprintf fmt "indirect: %a"
      Zone.pretty indirect
  | false, false ->
    Format.fprintf fmt "indirect: %a; direct: %a"
      Zone.pretty indirect
      Zone.pretty data

let pretty_debug = pretty_precise

(* Conversion to zone, used by default pretty printing *)
let to_zone d = Locations.Zone.join d.data d.indirect


(* Datatype *)

module Prototype = struct
  include Datatype.Serializable_undefined

  type t = deps = {
    data: Zone.t;
    indirect: Zone.t;
  }
  [@@deriving eq,ord]

  let name = "Deps"
  let pretty fmt d = Zone.pretty fmt (to_zone d)
  let hash fd = Hashtbl.hash (Zone.hash fd.data, Zone.hash fd.indirect)
  let reprs = List.map (fun z -> {data = z; indirect = z}) Zone.reprs
end

include Datatype.Make (Prototype)
include Prototype


(* Constructors *)

let bottom = {
  data = Locations.Zone.bottom;
  indirect = Locations.Zone.bottom;
}

let top = {
  data = Zone.top;
  indirect = Zone.top;
}

let data z = {
  data = z;
  indirect = Zone.bottom;
}

let indirect z = {
  data = Zone.bottom;
  indirect = z;
}


(* Mutators *)

let add_data d data =
  { d with data = Zone.join d.data data }

let add_indirect d indirect =
  { d with indirect = Zone.join d.indirect indirect }


(* Map *)

let map f d = {
  data = f d.data;
  indirect = f d.indirect;
}


(* Lattice *)

let is_included fd1 fd2 =
  Zone.is_included fd1.data fd2.data &&
  Zone.is_included fd1.indirect fd2.indirect

let join d1 d2 =
  if d1 == bottom then d2
  else if d2 == bottom then d1
  else {
    data = Zone.join d1.data d2.data;
    indirect = Zone.join d1.indirect d2.indirect;
  }

let narrow d1 d2 = {
  data = Zone.narrow d1.data d2.data;
  indirect = Zone.narrow d1.indirect d2.indirect;
}
