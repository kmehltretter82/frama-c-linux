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

include State_builder.Ref
    (Cil_datatype.Location)
    (struct
      let dependencies = []
      let name = "Current_loc"
      let default () = Cil_datatype.Location.unknown
    end)

let () = Log.set_current_source (fun () -> fst (get ()))

let with_loc loc f x =
  let oldLoc = get () in
  let finally () = set oldLoc in
  let work () = set loc; f x in
  Fun.protect ~finally work

let with_loc_opt loc_opt f x =
  match loc_opt with
  | None -> f x
  | Some loc -> with_loc loc f x

module Operators = struct
  type operation = UpdatedCurrentLoc

  let ( let<> ) loc f = with_loc loc f UpdatedCurrentLoc
  let ( let<?> ) loc_opt f = with_loc_opt loc_opt f UpdatedCurrentLoc
end
