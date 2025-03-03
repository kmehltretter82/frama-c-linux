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

let initial () =
  let module Analyzer = (val Analysis.current_analyzer ()) in
  let domain =
    (module Analyzer.Dom : Abstract.Domain.External
      with type state = Analyzer.Dom.state)
  in
  let interferences = Interferences.initial domain in
  Interferences.current := interferences; (* For Iterator *)
  interferences

let concurrent_writes shared_bases =
  let module Analyzer = (val Analysis.current_analyzer ()) in
  let module ALoc = Analysis_location in
  match Analyzer.Dom.get MtDomain.Domain.key with
  (* Domain disabled, no information about writes *)
  | None -> ALoc.Local.Set.empty
  (* Domain enabled *)
  | Some extract ->
    let add_aloc stmt cs state acc =
      let mt_state = extract state in
      let { MtDomain.written } = MtDomain.Domain.memory mt_state in
      let written_bases = Locations.Zone.get_bases written in
      if Base.SetLattice.(intersects (inject shared_bases) written_bases)
      then ALoc.Local.Set.add (stmt, cs) acc
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
          Callstack.Hashtbl.fold (add_aloc stmt) table acc
      else acc
    in
    let add_kf kf acc =
      match kf.Cil_types.fundec with
      | Declaration _ -> acc
      | Definition (fundec,_) ->
        List.fold_left add_stmt acc fundec.Cil_types.sallstmts
    in
    Globals.Functions.fold add_kf ALoc.Local.Set.empty

let shared_bases analysis_state =
  let shared_zones = analysis_state.MtThread.concurrent_accesses in
  match Locations.Zone.get_bases shared_zones with
  | Top -> assert false
  | Set zones ->  zones

let add_last_analysis analysis_state interferences =
  let module Analyzer = (val Analysis.current_analyzer ()) in
  let domain =
    (module Analyzer.Dom : Abstract.Domain.External
      with type state = Analyzer.Dom.state)
  in
  let get_state (stmt, cs) =
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
  let bases = shared_bases analysis_state in
  let writes = concurrent_writes bases in
  let thread = analysis_state.curr_thread.th_eva_thread in
  let res =
    Interferences.add_last_analysis ~domain ~get_state
      interferences thread writes bases
  in
  match res with
  | Updated ->
    MtThread.iter_threads analysis_state
      (fun th -> MtThread.ThreadState.recompute_because th InterferencesChanged)
  | NoChanges ->
    ()
