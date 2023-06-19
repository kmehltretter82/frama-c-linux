(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2025                                               *)
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

open MtCfgTypes
open MtThread


val make_cfg: thread -> cfg

(** Remove nodes without multi-thread contents in the automata given by
    the start node, and returns the new start node. Nodes that are concurrent
    according to keep and {CfgNode.must_be_in_cfg}. *)
val remove_superfluous_nodes : keep:var_access_kind -> cfg -> cfg


val dot_fprint_graph:
  Format.formatter -> cfg -> (Cil_types.stmt -> string) -> unit


(** {1 Memory accesses in a cfg} *)

val cfg_accesses: thread -> cfg -> AccessesByZoneNode.map



(** {1 Dataflow on a cfg} *)




val update_cfg_contexts: analysis_state -> thread -> unit
