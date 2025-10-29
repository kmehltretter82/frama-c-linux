(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

type computation_state = Self.computation_state =
  | NotComputed | Computing | Computed | Aborted
let current_computation_state = Self.ComputationState.get
let register_computation_hook ?on f =
  let f' = match on with
    | None -> f
    | Some s -> fun s' -> if s = s' then f s
  in
  Self.ComputationState.add_hook_on_change f'

let is_computed = Self.is_computed
let self = Self.state
let emitter = Eva_utils.emitter

type results = Function_calls.results = Complete | Partial | NoResults
type status = Function_calls.analysis_status =
    Unreachable | SpecUsed | Builtin of string | Analyzed of results
let status kf =
  match Function_calls.analysis_status kf with
  | Analyzed Complete as status ->
    if is_computed () then status else Analyzed Partial
  | status -> status

let use_spec_instead_of_definition =
  Function_calls.use_spec_instead_of_definition ?recursion_depth:None

let save_results kf =
  try Function_calls.save_results (Kernel_function.get_definition kf)
  with Kernel_function.No_Definition -> false

(* Builds the analyzer if needed, and run the analysis. *)
let force_compute () =
  Ast.compute ();
  Parameters.configure_precision ();
  if not (Kernel.AuditCheck.is_empty ()) then
    Eva_audit.check_configuration (Kernel.AuditCheck.get ());
  let kf, lib_entry = Globals.entry_point () in
  Engine.reset_analyzer ();
  (* The new analyzer can be accessed through hooks *)
  Self.ComputationState.set Computing;
  let module Analyzer = (val Engine.current_analyzer ()) in
  try Analyzer.Compute.compute_from_entry_point ~lib_entry kf
  with Self.Abort ->
    Self.(ComputationState.set Aborted);
    Self.error "The analysis has been aborted: results are incomplete."

let compute () =
  (* Nothing to recompute when Eva has already been computed. This boolean
      is automatically cleared when an option of Eva changes, because they
      are registered as dependencies on [Self.state] in {!Parameters}.*)
  if not (is_computed ()) then force_compute ()

let compute =
  let name = "Eva.Analysis.compute" in
  fst (State_builder.apply_once name [ Self.state ] compute)

let () = Parameters.ForceValues.set_output_dependencies [Self.state]

let main () = if Parameters.ForceValues.get () then compute ()
let () = Boot.Main.extend main

let abort () =
  if Self.ComputationState.get () = Computing
  then Iterator.signal_abort ~kill:false
