(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2023                                               *)
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

let () = Db.Value.compute := Analysis.compute
let () = Parameters.ForceValues.set_output_dependencies [Self.state]

let main () =
  (* Value computations *)
  if Parameters.ForceValues.get () then Analysis.compute ();
  if Analysis.is_computed () then Red_statuses.report ()

let () = Db.Main.extend main

let () = Db.Value.initial_state_only_globals := Analysis.cvalue_initial_state


(*
Local Variables:
compile-command: "make -C ../../.."
End:
*)
