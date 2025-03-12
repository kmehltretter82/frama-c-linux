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

open Lattice_bounds

module ALoc = Analysis_location.Local
module AlocMap = ALoc.Map
module MutexesMap = Map.Make (Mutex.Set)

type thread_id = int

let dkey = Self.register_category "interferences"

(* Set of interferences stored as a map from the set of mutexes surely
   locked to the corresponding interferences states. *)

module ByMutexes (Dom : Abstract.Domain.External) =
struct
  type t = Dom.t or_top MutexesMap.t

  let pretty : Format.formatter -> t -> unit =
    Pretty_utils.pp_iter2 ~sep:"@ " ~between:" -> "
      MutexesMap.iter Mutex.Set.pretty (Top.pretty Dom.pretty)

  let equal : t -> t -> bool = MutexesMap.equal (Top.equal Dom.equal)
end


(* Set of interferences stored as a map from analysis location to the
   interference generated at this control state. *)

module ByAnalysisLocation (Dom : Abstract.Domain.External) =
struct
  type elt =
    {
      state : Dom.t or_top;
      widening_counter : int;
    }

  type t = elt AlocMap.t

  let empty = AlocMap.empty

  module DomOrTop =
  struct
    let top_join join = Top.join (fun s1 s2 -> `Value (join s1 s2))
    let join = top_join Dom.join
    let widen kf stmt = top_join (Dom.widen kf stmt)
  end

  let add_and_widen (aloc : ALoc.t) (state : Dom.t or_top) : t -> t =
    let update = function
      | None -> (* No previous entry *)
        let widening_delay = Parameters.WideningDelay.get () in
        Some { state ; widening_counter = widening_delay - 1 }

      | Some previous -> (* Some previous entry *)
        let state = DomOrTop.join previous.state state in
        let state, widening_counter =
          if previous.widening_counter > 0 then
            (* No widening *)
            state, previous.widening_counter
          else begin
            (* Widen the interferences between the previous and current
               state. *)
            let widening_period = Parameters.WideningPeriod.get () in
            let stmt, cs = aloc in
            let kf = Callstack.top_kf cs in
            DomOrTop.widen kf stmt previous.state state, widening_period
          end
        in
        Some { state ; widening_counter = widening_counter - 1 }
    in
    AlocMap.update aloc update

  let group_by_mutexes (map : t) : (Dom.t or_top) MutexesMap.t =
    let add _aloc { state ; _ } acc_map =
      let locked_mutexes =
        match state with
        | `Top -> Mutex.Set.empty
        | `Value state ->
          match Dom.get Mt_domain.Domain.key with
          | None -> Mutex.Set.empty
          | Some extract ->
            Mt_domain.Domain.mutexes (extract state)
            |> Mt_mutex.Register.locked_mutexes
      in
      let update = function
        | None -> Some state
        | Some previous -> Some (DomOrTop.join previous state)
      in
      MutexesMap.update locked_mutexes update acc_map
    in
    AlocMap.fold add map MutexesMap.empty
end


(* Interferences Functor *)

module Make (Dom : Abstract.Domain.External) =
struct
  module ThreadTable = Thread.Hashtbl
  module ByAnalysisLocation = ByAnalysisLocation (Dom)
  module ByMutexes = ByMutexes (Dom)

  type t = {
    states_by_aloc : ByAnalysisLocation.t ThreadTable.t;
    states_by_mutexes :  ByMutexes.t ThreadTable.t;
    mutable shared_bases : Base.Hptset.t;
  }

  let current = {
    states_by_aloc = ThreadTable.create 13;
    states_by_mutexes = ThreadTable.create 13;
    shared_bases = Base.Hptset.empty;
  }

  let reset () =
    ThreadTable.reset current.states_by_aloc;
    ThreadTable.reset current.states_by_mutexes;
    current.shared_bases <- Base.Hptset.empty

  let is_empty () =
    ThreadTable.length current.states_by_aloc = 0

  (* Interference registration *)

  type add_result =
    | Updated
    | NoChanges

  let add_last_analysis
      ~(get_state : Analysis_location.local -> Dom.t or_top_bottom)
      thread concurrent_writes shared_bases =
    (* Retrieve the interferences  *)
    let old_states_by_aloc =
      ThreadTable.find_def current.states_by_aloc thread
        ByAnalysisLocation.empty
    in
    let new_states_by_aloc =
      let add aloc acc_map =
        let open TopBottom.Operators in
        let state =
          (* Retrieve state at analysis location *)
          let+ state = get_state aloc in
          Dom.filter `Print shared_bases state
        in
        match state with
        | `Bottom -> acc_map (* no interference to add *)
        | `Top | `Value _ as state ->
          if Top.is_top state then
            Self.warning ~once:false ~source:(ALoc.pos aloc)
              "Imprecise interference computed";
          ByAnalysisLocation.add_and_widen aloc state acc_map
      in
      ALoc.Set.fold add concurrent_writes old_states_by_aloc
    in
    (* Check for changes *)
    let new_states_by_mutexes =
      ByAnalysisLocation.group_by_mutexes new_states_by_aloc
    and old_states_by_mutexes =
      ThreadTable.find_opt current.states_by_mutexes thread
    in
    let same_interferences = match old_states_by_mutexes with
      | None -> MutexesMap.is_empty new_states_by_mutexes
      | Some old -> ByMutexes.equal new_states_by_mutexes old
    in
    let same_shared_bases =
      Base.Hptset.equal current.shared_bases shared_bases
    in
    (* Update the record *)
    ThreadTable.replace current.states_by_aloc thread new_states_by_aloc;
    ThreadTable.replace current.states_by_mutexes thread new_states_by_mutexes;
    current.shared_bases <- shared_bases;
    (* Debug printing *)
    let pp_aloc fmt = Format.fprintf fmt "@[<hov 2>%a@]" ALoc.pretty in
    let pp_aloc_set =
      Pretty_utils.pp_iter ~pre:"@[<v>" ~sep:",@ " ALoc.Set.iter pp_aloc
    in
    Self.debug ~dkey
      "concurrent writes: @[%a@]@.\
       shared bases: @[%a@]@.\
       interferences: @[%a@]@."
      pp_aloc_set concurrent_writes
      Base.Hptset.pretty shared_bases
      ByMutexes.pretty new_states_by_mutexes;
    if not (same_interferences && same_shared_bases)
    then Updated
    else NoChanges

  (* Interference injection *)

  let applicable (state : Dom.t) : Dom.t or_top_bottom =
    let threads, mutexes = match Dom.get Mt_domain.Domain.key with
      (* Domain disabled, no information about threads and mutexes *)
      | None -> Mt_thread.Register.empty, Mutex.Set.empty
      (* Domain enabled *)
      | Some extract ->
        let mt_state = extract state in
        Mt_domain.Domain.threads mt_state,
        Mt_domain.Domain.mutexes mt_state |> Mt_mutex.Register.locked_mutexes
    in
    let dom_join s1 s2 = `Value (Dom.join s1 s2) in
    let add mutexes' state' acc_state =
      if Mutex.Set.disjoint mutexes mutexes'
      (* No mutexes in common, this interference is applicable *)
      then TopBottom.join dom_join acc_state (state' :> _ or_top_bottom)
      (* At least one mutex in common, this interfence cannot apply *)
      else acc_state
    in
    let add_thread thread state_map acc_state =
      let is_current_thread = Thread.(equal thread (current ())) in
      let maybe_running =
        match Mt_thread.Register.find thread threads with
        (* Thread status is uknown, consider that the thread might be running*)
        | None -> true
        (* Thread status is known *)
        | Some status -> Mt_utils.Trilean.maybe_true status.running
      in
      let can_thread_interfere = maybe_running && not is_current_thread in
      if can_thread_interfere
      then MutexesMap.fold add state_map acc_state
      else acc_state
    in
    ThreadTable.fold add_thread current.states_by_mutexes `Bottom

  let inject (state : Dom.t) : Dom.t =
    let need_injection =
      match Dom.get Mt_domain.Domain.key with
      (* Domain disabled, no interference injection *)
      | None -> false
      (* Domain enabled *)
      | Some extract ->
        let mt_state = extract state in
        let memory = Mt_domain.Domain.memory mt_state in
        let zone = Locations.Zone.join memory.read memory.written in
        match Locations.Zone.get_bases zone with
        | Top ->
          (* Shared memory is Top, always inject *)
          Self.warning ~current:true ~once:true
            "imprecise memory footprint computed at this point";
          true
        | Set bases ->
          (* Inject only if the read/written memory intersects shared memory *)
          Base.Hptset.intersects bases current.shared_bases
    in
    if not need_injection
    then state
    else begin
      Self.debug ~dkey ~current:true ~once:true
        "inject threads interferences at this point";
      match applicable state with
      | `Top -> Dom.top
      | `Bottom -> state
      | `Value interferences_state ->
        let dummy_kf = Kernel_function.dummy () in
        let result =
          Dom.reuse dummy_kf current.shared_bases
            ~current_input:state ~previous_output:interferences_state
        in
        Dom.join state result
    end
end
