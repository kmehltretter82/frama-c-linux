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

(** General Eva requests registered in the server. *)

open Cil_types

type evaluation_point =
  | Initial
  | Pre of kernel_function
  | Stmt of kernel_function * stmt

(* Returns the evaluation point of a marker.
   @raise Not_found if the marker cannot be evaluated. *)
val marker_evaluation_point: Printer_tag.localizable -> evaluation_point

(* Converts an ACSL lval into a C lval.
   @raise Not_found if the conversion fails. *)
val term_lval_to_lval: kernel_function option -> term_lval -> lval
