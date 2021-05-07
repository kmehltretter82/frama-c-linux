(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2021                                               *)
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

(** Registers Eva annotations:
    - slevel annotations: "slevel default", "slevel merge" and "slevel i"
    - loop unroll annotations: "loop unroll term"
    - value partitioning annotations: "split term" and "merge term"
    - subdivision annotations: "subdivide i"

    Widen hints annotations are still registered in !{widen_hints_ext.ml}. *)

type slevel_annotation =
  | SlevelMerge
  | SlevelDefault
  | SlevelLocal of int
  | SlevelFull

type unroll_annotation =
  | UnrollAmount of Cil_types.term
  | UnrollFull

type split_kind = Static | Dynamic

type flow_annotation =
  | FlowSplit of Cil_types.term * split_kind
  | FlowMerge of Cil_types.term

type taint_annotation = Cil_types.term list

type allocation_kind = By_stack | Fresh | Fresh_weak | Imprecise

val get_slevel_annot : Cil_types.stmt -> slevel_annotation option
val get_unroll_annot : Cil_types.stmt -> unroll_annotation list
val get_flow_annot : Cil_types.stmt -> flow_annotation list
val get_subdivision_annot : Cil_types.stmt -> int list
val get_taint_annot : Cil_types.stmt -> taint_annotation list
val get_allocation: Cil_types.stmt -> allocation_kind

val add_slevel_annot : emitter:Emitter.t -> loc:Cil_types.location ->
  Cil_types.stmt -> slevel_annotation -> unit
val add_unroll_annot : emitter:Emitter.t -> loc:Cil_types.location ->
  Cil_types.stmt -> unroll_annotation -> unit
val add_flow_annot : emitter:Emitter.t -> loc:Cil_types.location ->
  Cil_types.stmt -> flow_annotation -> unit
val add_subdivision_annot : emitter:Emitter.t -> loc:Cil_types.location ->
  Cil_types.stmt -> int -> unit
val add_taint_annot : emitter:Emitter.t -> loc:Cil_types.location ->
  Cil_types.stmt -> taint_annotation -> unit
