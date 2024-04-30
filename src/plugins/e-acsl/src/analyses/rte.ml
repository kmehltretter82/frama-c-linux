(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2024                                               *)
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

(* ************************************************************************** *)
(** {2 Exported code} *)
(* ************************************************************************** *)

let stmt ?warn:_ kf stmt =
  RteGen.Visit.get_annotations_stmt kf stmt

let exp ?warn:_ kf stmt e =
  RteGen.Visit.get_annotations_exp kf stmt e

let get_state_selection_with_dependencies () =
  State_selection.with_dependencies RteGen.Api.self

(*
Local Variables:
compile-command: "make -C ../../../../.."
End:
*)
