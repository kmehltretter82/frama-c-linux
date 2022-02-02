(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2021                                               *)
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

open Cil_types
module Error = Error.Make(struct let phase = Options.Dkey.translation end)

let get_first_inner_stmt stmt =
  match stmt.labels, stmt.skind with
  | [], _ -> stmt
  | _ :: _, Block { bstmts = dest_stmt :: _ } ->
    dest_stmt
  | labels, _ ->
    Options.fatal "Unexpected stmt:\nlabels: [%a]\nstmt: %a"
      (Pretty_utils.pp_list ~sep:"; " Cil_types_debug.pp_label) labels
      Printer.pp_stmt stmt

let get_stmt kf llabel =
  let stmt = match llabel with
    | StmtLabel { contents = stmt } -> stmt
    | BuiltinLabel Here -> Error.not_yet "Label 'Here'"
    | BuiltinLabel(Old | Pre) ->
      (try Kernel_function.find_first_stmt kf
       with Kernel_function.No_Statement -> assert false (* Frama-C invariant*))
    | BuiltinLabel(Post) ->
      (try Kernel_function.find_return kf
       with Kernel_function.No_Statement -> assert false (* Frama-C invariant*))
    | BuiltinLabel _ ->
      Error.not_yet (Format.asprintf "Label '%a'" Printer.pp_logic_label llabel)
    | FormalLabel _ ->
      Error.not_yet "FormalLabel"
  in
  (* the pointed statement has been visited and modified by the injector:
     get its new version. *)
  get_first_inner_stmt stmt

(*
Local Variables:
compile-command: "make -C ../../../../.."
End:
*)
