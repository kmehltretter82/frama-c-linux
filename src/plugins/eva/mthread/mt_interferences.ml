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

let concurrent_writes shared_bases =
  let module Analyzer = (val Analysis.current_analyzer ()) in
  match Analyzer.Dom.get Mt_domain.Domain.key with
  (* Domain disabled, no information about writes *)
  | None -> Position.Local.Set.empty
  (* Domain enabled *)
  | Some _extract ->
    let add_pos stmt cs _state acc =
      let pos = Position.local stmt cs in
      (* TODO: Maybe take the memory read/written for all callstacks of the
         given statement? (can be done directly by Inout_access). *)
      let filter = Inout_access.keep_globals_only in
      let accesses = Inout_access.at ~filter pos in
      let written_bases = Locations.Zone.get_bases accesses.write in
      if Base.SetLattice.(intersects (inject shared_bases) written_bases)
      then Position.Local.Set.add (stmt, cs) acc
      else acc
    in
    let add_stmt acc stmt =
      let is_write_stmt = match stmt.Cil_types.skind with
        | Cil_types.Instr (Set _ | Call _ | Local_init _) -> true
        | _ -> false
      in
      if is_write_stmt
      then match Analyzer.get_stmt_state_by_callstack ~after:true stmt with
        | `Top | `Bottom -> acc (* TODO: handle Tops *)
        | `Value table ->
          Callstack.Hashtbl.fold (add_pos stmt) table acc
      else acc
    in
    let add_kf kf acc =
      match kf.Cil_types.fundec with
      | Declaration _ -> acc
      | Definition (fundec,_) ->
        List.fold_left add_stmt acc fundec.Cil_types.sallstmts
    in
    Globals.Functions.fold add_kf Position.Local.Set.empty

let shared_bases analysis_state =
  let shared_zones = analysis_state.Mt_thread.concurrent_accesses in
  match Locations.Zone.get_bases shared_zones with
  | Top -> assert false
  | Set zones ->  zones

let add_last_analysis analysis_state =
  let module Analyzer = (val Analysis.current_analyzer ()) in
  let bases = shared_bases analysis_state in
  let writes = concurrent_writes bases in
  let thread = analysis_state.curr_thread.th_eva_thread in
  match Analyzer.Interferences.add_last_analysis thread writes bases with
  | Updated ->
    Mt_thread.iter_threads analysis_state
      (fun th -> Mt_thread.ThreadState.recompute_because th InterferencesChanged)
  | NoChanges ->
    ()
