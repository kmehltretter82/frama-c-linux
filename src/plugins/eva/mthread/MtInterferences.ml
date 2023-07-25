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

let concurrent_writes analysis_state =
  let module ALSet = Interferences.AnalysisLocation.Set in
  let open MtCfgTypes in
  let is_write = function
    | MtTypes.Read -> false
    | Write _ -> true
  in
  let add_accesses (rw, node, _id) (acc : ALSet.t) =
    if not (is_write rw)
    then acc
    else
      let seq =
        CfgNode.node_stmt node |>
        List.to_seq |>
        Seq.map (fun stmt -> node.cfgn_stack, stmt)
      in
      ALSet.add_seq seq acc
  in
  let add_zone_accesses acc (_zone, node_id_set) =
    MtCfgTypes.SetNodeIdAccess.fold add_accesses node_id_set acc
  in
  analysis_state.MtThread.concurrent_accesses_by_nodes |>
  List.fold_left add_zone_accesses ALSet.empty |>
  ALSet.to_seq |>
  List.of_seq

let shared_bases analysis_state =
  let shared_zones = analysis_state.MtThread.precise_concurrent_accesses in
  match Locations.Zone.get_bases shared_zones with
  | Top -> assert false
  | Set zones ->  zones

let add_last_analysis analysis_state interferences =
  let writes = concurrent_writes analysis_state in
  let bases = shared_bases analysis_state in
  let thread = analysis_state.curr_thread.th_eva_thread in
  Interferences.add_last_analysis interferences thread writes bases
