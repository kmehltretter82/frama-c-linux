(**************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2023                                               *)
(*    CEA (Commissariat a l'energie atomique et aux energies              *)
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

open Cil_types

type probe = {
  id : int;
  name : string ;
  stmt : stmt option ;
  loc : location ;
}

let create =
  let id = ref (-1) in
  fun ~loc ?stmt ~name () ->
    incr id; { id = !id ; loc ; stmt ; name }

module S =
struct
  include Datatype.Undefined
  let name = "WP.Conditions.Probe.t"
  let reprs = [{
      loc=List.hd Cil_datatype.Location.reprs;
      stmt = None; name =""; id=1
    }]
  type t = probe
  let hash x = x.id
  let equal x y = Int.equal x.id y.id
  let compare x y = Int.compare x.id y.id
  let pretty fmt p = Format.fprintf fmt "#%d(%s)" p.id p.name
end

include Datatype.Make_with_collections(S)

(**************************************************************************)
