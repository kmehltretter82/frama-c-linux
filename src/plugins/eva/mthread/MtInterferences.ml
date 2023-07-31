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

let initial () =
  let module Analyzer = (val Analysis.current_analyzer ()) in
  let domain =
    (module Analyzer.Dom : Abstract.Domain.External
      with type state = Analyzer.Dom.state)
  in
  let interferences = Interferences.initial domain in
  Interferences.current := interferences; (* For Iterator *)
  interferences


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
  let module Analyzer = (val Analysis.current_analyzer ()) in
  let domain =
    (module Analyzer.Dom : Abstract.Domain.External
      with type state = Analyzer.Dom.state)
  in
  let get_state (cs,stmt) =
    let open Lattice_bounds.TopBottom.Operators in
    let* state_table =
      Analyzer.get_stmt_state_by_callstack ~selection:[cs] ~after:true stmt
    in
    try
      `Value (Callstack.Hashtbl.find state_table cs)
    with Not_found ->
      MtOptions.result "cannot find %a at %a"
        Callstack.pretty cs
        Printer.pp_location (Cil_datatype.Stmt.loc stmt);
      Analyzer.get_stmt_state ~after:true stmt
  in
  let writes = concurrent_writes analysis_state in
  let bases = shared_bases analysis_state in
  let thread = analysis_state.curr_thread.th_eva_thread in
  Interferences.add_last_analysis ~domain ~get_state
    interferences thread writes bases
