(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Cil_types

open Pdg_types

type nodes = Pdg_aux.NS.t
type result = nodes Kernel_function.Map.t

val initial_nodes:
  skip:Locations.Zone.t -> kernel_function -> stmt -> PdgTypes.Node.t list

val nodes_impacted_by_stmts:
  ?skip:Locations.Zone.t -> ?restrict:Locations.Zone.t -> ?reason:bool ->
  kernel_function -> stmt list ->
  result * nodes Kernel_function.Map.t * Reason_graph.reason
(** nodes in returned map are initial nodes *)

val nodes_impacted_by_nodes:
  ?skip:Locations.Zone.t -> ?restrict:Locations.Zone.t -> ?reason:bool ->
  kernel_function -> PdgTypes.Node.t list ->
  result * nodes Kernel_function.Map.t * Reason_graph.reason
(** nodes in returned map are initial nodes *)

val stmts_impacted:
  ?skip:Locations.Zone.t -> reason:bool ->
  kernel_function -> stmt list -> stmt list

val nodes_impacted:
  ?skip:Locations.Zone.t -> reason:bool ->
  kernel_function -> PdgTypes.Node.t list -> nodes


val result_to_nodes: result -> nodes
val nodes_to_stmts: nodes -> stmt list
val impact_in_kf: result -> Cil_types.kernel_function -> nodes

val skip: unit -> Locations.Zone.t
(** computed from the option [-impact-skip] *)
