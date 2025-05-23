(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** General Eva requests registered in the server. *)

open Cil_types

type evaluation_point =
  | Initial
  | Pre of kernel_function
  | Stmt of kernel_function * stmt

(** Returns the evaluation point of a marker.
    @raise Not_found if the marker cannot be evaluated. *)
val marker_evaluation_point: Printer_tag.localizable -> evaluation_point

(** Executes function [f] with an updated global printer which prints
    any varinfo as a lvalue marker at the given evaluation point. *)
val with_updated_varinfo_printer: evaluation_point -> (unit -> 'a) -> 'a

(** Converts an ACSL lval into a C lval.
    @raise Not_found if the conversion fails. *)
val term_lval_to_lval: kernel_function option -> term_lval -> lval
