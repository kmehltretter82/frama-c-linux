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

type thread_id = int

let dkey = Self.register_category "interferences"


module ThreadTable = Thread.Hashtbl
module MutexesMap =
struct
  include Map.Make (Mutex.Set)

  let pretty pp_state =
    Pretty_utils.pp_iter2 ~sep:"@ " ~between:" -> "
      iter Mutex.Set.pretty pp_state
end

module Make (Dom : Abstract.Domain.External) =
struct
  type state = Dom.state

  type widening = {
    widening_counter : int;
  }

  type state_with_widening = state * widening

  type t = {
    states : (state_with_widening or_top MutexesMap.t) ThreadTable.t;
    mutable shared_bases : Base.Hptset.t;
  }

  let get_state : state_with_widening or_top -> state or_top = function
    | `Top -> `Top
    | `Value (state, _) -> `Value state

  let pp_state pp_dom fmt (state : state_with_widening or_top) =
    let pp_aux fmt (dom_state, _) = pp_dom fmt dom_state in
    Format.fprintf fmt "%a" (Top.pretty pp_aux) state

  let initial () = {
    states = ThreadTable.create 13;
    shared_bases = Base.Hptset.empty;
  }

  let current =
    ref {
      states = ThreadTable.create 13;
      shared_bases = Base.Hptset.empty;
    }

  let is_empty { states } =
    ThreadTable.length states = 0


  (* Interference registration *)

  type add_result =
    | Updated
    | NoChanges

  let add_last_analysis
      ~(get_state : Analysis_location.local -> state or_top_bottom)
      interferences thread concurrent_writes shared_bases =
    let module ALoc = Analysis_location in
    match Dom.get Mt_domain.Domain.key with
    | None -> NoChanges (* Domain disabled, no interference computation *)
    | Some extract ->
      let widening_delay = Parameters.WideningDelay.get () in
      let widening_period = Parameters.WideningPeriod.get () in

      let add_to_map aloc acc_map =
        let open TopBottom.Operators in
        let state =
          (* Retrieve state at analysis location *)
          let+ state = get_state aloc in
          let mutexes_status = Mt_domain.Domain.mutexes (extract state) in
          let mutexes = Mt_mutex.Register.locked_mutexes mutexes_status in
          Dom.filter `Print shared_bases state, mutexes
        in
        match state with
        | `Bottom -> acc_map (* no interference to add *)
        | `Top ->
          Self.warning ~once:false ~source:(fst (Cil_datatype.Stmt.loc (fst aloc)))
            "Imprecise interference computed";
          MutexesMap.add Mutex.Set.empty `Top acc_map
        | `Value (state, mutexes) ->
          let update = function
            | Some `Top -> Some `Top
            | None ->
              let widening_counter = widening_delay - 1 in
              Some (`Value (state, { widening_counter }))
            | Some `Value (previous, w) ->
              Some (`Value (Dom.join previous state, w))
          in
          MutexesMap.update mutexes update acc_map
      in

      let widen_interference_states prev_states curr_states =
        let equal = ref true in
        let widen_one_state key curr_value =
          let previous_value = MutexesMap.find_opt key prev_states in
          match curr_value, previous_value with
          | _, Some `Top -> `Top
          | `Top, _ ->
            equal := false;
            `Top
          | `Value v, None ->
            equal := false;
            `Value v
          | `Value (curr, _), Some `Value (previous, { widening_counter }) ->
            let next, widening_counter =
              if widening_counter > 0 then
                (* No widening *)
                Dom.join previous curr, widening_counter
              else begin
                (* Widen the interferences between the previous and current
                   state. Use the widen hints on the concurrent writes. *)
                let widened_state =
                  ALoc.Local.Set.fold
                    (fun (stmt, cs) acc ->
                       let kf = Callstack.top_kf cs in
                       let widened =
                         Dom.widen kf stmt previous (Dom.join previous curr)
                       in
                       Dom.join widened acc)
                    concurrent_writes
                    previous
                in
                widened_state, widening_period
              end
            in
            let widening_counter = widening_counter - 1 in
            equal := !equal && (Dom.equal previous next);
            `Value (next, { widening_counter })
        in
        let next_states = MutexesMap.mapi widen_one_state curr_states in
        next_states, !equal
      in

      let { states } = interferences in
      (* Compute new interferences and check that they are different than the
         previous computed interferences. *)
      let old_interferences =
        ThreadTable.find_def states thread MutexesMap.empty
      in
      let new_interferences =
        ALoc.Local.Set.fold add_to_map concurrent_writes MutexesMap.empty
      in
      let new_interferences, same_mutexes_map =
        widen_interference_states old_interferences new_interferences
      in
      let same_shared_bases =
        Base.Hptset.equal interferences.shared_bases shared_bases
      in
      let pp_aloc fmt = Format.fprintf fmt "@[<hov 2>%a@]" ALoc.Local.pretty in
      let pp_aloc_set =
        Pretty_utils.pp_iter ~pre:"@[<v>" ~sep:",@ " ALoc.Local.Set.iter pp_aloc
      in
      Self.debug ~dkey
        "concurrent writes: @[%a@]@.\
         shared bases: @[%a@]@.\
         interferences: @[%a@]@."
        pp_aloc_set concurrent_writes
        Base.Hptset.pretty shared_bases
        (MutexesMap.pretty (pp_state Dom.pretty)) new_interferences;
      if not (same_mutexes_map && same_shared_bases) then begin
        (* Add the computed interferences to the table *)
        ThreadTable.replace states thread new_interferences;
        interferences.shared_bases <- shared_bases;
        Updated
      end else
        NoChanges


  (* Interference injection *)

  let applicable (interferences : t) (state : state) : state or_top_bottom =
    let threads, mutexes = match Dom.get Mt_domain.Domain.key with
      (* Domain disabled, no information about threads and mutexes *)
      | None -> Mt_thread.Register.empty, Mutex.Set.empty
      (* Domain enabled *)
      | Some extract ->
        let mt_state = extract state in
        Mt_domain.Domain.threads mt_state,
        Mt_domain.Domain.mutexes mt_state |> Mt_mutex.Register.locked_mutexes
    in
    let { states } = interferences in
    let dom_join s1 s2 = `Value (Dom.join s1 s2) in
    let add mutexes' state' acc_state =
      let state' = get_state state' in
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
    ThreadTable.fold add_thread states `Bottom

  let inject (state : state) : state =
    let interferences = !current in
    let { shared_bases } = interferences in
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
          Base.Hptset.intersects bases shared_bases
    in
    if not need_injection
    then state
    else begin
      Self.debug ~dkey ~current:true ~once:true
        "inject threads interferences at this point";
      match applicable interferences state with
      | `Top -> Dom.top
      | `Bottom -> state
      | `Value interferences_state ->
        let dummy_kf = Kernel_function.dummy () in
        let result =
          Dom.reuse dummy_kf shared_bases
            ~current_input:state ~previous_output:interferences_state
        in
        Dom.join state result
    end

  let is_empty () = is_empty !current
end
