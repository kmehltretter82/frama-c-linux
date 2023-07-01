(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2023                                               *)
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

open Lattice_bounds

type analysis_location = Callstack.t * Cil_types.stmt
type thread_id = int


(* Threads modelization *)

module Thread =
struct
  type t = MtThread.thread

  let main () =
    MtThread.main ()

  let map_arguments kf args =
    let formals = Kernel_function.get_formals kf in
    try
      List.combine formals args
    with Invalid_argument _ ->
      Self.abort
        "Arguments mismatch in thread creation; function %s expected %d \
        arguments, but %d were given"
        (Kernel_function.get_name kf) (List.length formals) (List.length args)

  let spawn name stmt kf args =
    let name = MtUtils.Name.extract_of_cvalue name in
    let name = MtUtils.Result.value name in
    let args = map_arguments kf args in
    MtThread.create name stmt kf args

  let set_current thread =
    MtDomain.set_current thread
end


(* Analysis location *)

module AnalysisLocation =
  Datatype.Pair_with_collections
    (Callstack)
    (Cil_datatype.Stmt)
    (struct let module_name = "ProgramLocation" end)


(* Interferences type *)

module ThreadTable = MtThread.Hashtbl

type 'a interferences = {
  states : ('a or_top) ThreadTable.t;
  structure : 'a Abstract.Domain.structure;
}

type t = Interferences : 'a interferences -> t

let initial () =
  let module Analyzer = (val Analysis.current_analyzer ()) in
  Interferences {
    states = ThreadTable.create 13;
    structure = Analyzer.Dom.structure
  }

let structure_mismatch () =
  Self.abort 
    "different sets of abstract domains or structure used between two thread \
    analyses"


(* Interference registration *)

let add_last_analysis interferences thread concurrent_writes shared_bases =
  let module Analyzer = (val Analysis.current_analyzer ()) in
  let module Dom = Analyzer.Dom in
  (* Add interferences one by one *)
  let add acc_state (cs,stmt) =
    let open TopBottom.Operators in
    let state =
      let+ state_table =
        Analyzer.get_stmt_state_by_callstack ~selection:[cs] ~after:true stmt
      in
      let state = Callstack.Hashtbl.find state_table cs in
      Dom.filter `Print shared_bases state
    in
    let dom_join s1 s2 = `Value (Dom.join s1 s2) in
    TopBottom.join dom_join acc_state state
  in
  let new_interference_state = List.fold_left add `Bottom concurrent_writes in
  Self.result "concurrent writes: @[%a@]@.abstract value: @[%a@]@."
    (Pretty_utils.pp_list AnalysisLocation.pretty) concurrent_writes
    (TopBottom.pretty Dom.pretty) new_interference_state;
  (* Add the computed interferences to the table *)
  let Interferences { states; structure } = interferences in
  match Abstract.Domain.eq_structure structure Dom.structure with
  | None -> structure_mismatch ()
  | Some Eq ->
    match new_interference_state with
    | `Bottom -> 
      ThreadTable.remove states thread
    | (`Top | `Value _ as new_interference_state) -> 
      ThreadTable.replace states thread new_interference_state


(* Interference injection *)

let applicable_interferences
    (type a)
    (interferences : t)
    (analyzer : (module Analysis.S with type Dom.state = a))
    (state : a)
    : a or_top_bottom =
  let module Analyzer = (val analyzer : Analysis.S with type Dom.state = a) in
  let module Dom = Analyzer.Dom in
  let Interferences { states; structure } = interferences in
  match Abstract.Domain.eq_structure structure Dom.structure with
  | None -> structure_mismatch ()
  | Some Eq ->
    let dom_join s1 s2 = `Value (Dom.join s1 s2) in
    let add thread thread_state acc_state =
      let can_thread_interfere =
        not (MtThread.equal thread (MtDomain.current ())) &&
        match Dom.get MtDomain.Domain.key with
        (* Domain disabled, consider that every interference is potentially
           applicable *)
        | None -> true
        (* Domain enabled *)
        | Some extract ->
          let threads = MtDomain.Domain.threads (extract state) in
          match MtThread.Register.find thread threads with
          (* Thread status is uknown; this can happen for several reason,
             consider that the thread is running*)
          | None -> true
          (* Thread status is known *)
          | Some status -> MtUtils.Trilean.maybe_true status.running
      in
      if can_thread_interfere
      then TopBottom.join dom_join acc_state (thread_state :> _ or_top_bottom)
      else acc_state
    in
    ThreadTable.fold add states `Bottom

