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

open Lattice_bounds

type 'a domain = (module Abstract.Domain.External with type state = 'a)
type thread_id = int

let dkey = Self.register_category "interferences"


(* Interferences type *)

module ThreadTable = Thread.Hashtbl
module MutexesMap =
struct
  include Map.Make (Mutex.Set)

  let pretty pp_state =
    Pretty_utils.pp_iter2 ~sep:"@ " ~between:" -> "
      iter Mutex.Set.pretty (Top.pretty pp_state)
end

type 'a interferences = {
  states : (('a or_top) MutexesMap.t) ThreadTable.t;
  structure : 'a Abstract.Domain.structure;
  mutable shared_bases : Base.Hptset.t;
}

type t = Interferences : 'a interferences -> t


let initial (type a) (domain : a domain) =
  let module Domain = (val domain) in
  Interferences {
    states = ThreadTable.create 13;
    structure = Domain.structure;
    shared_bases = Base.Hptset.empty;
  }

let current =
  ref (Interferences {
      states = ThreadTable.create 13;
      structure = Abstract.Domain.Unit;
      shared_bases = Base.Hptset.empty;
    })

let is_empty (Interferences { states }) =
  ThreadTable.length states = 0

let structure_mismatch () =
  Self.abort
    "different sets of abstract domains or structure used between two thread \
     analyses"


(* Interference registration *)

let add_last_analysis
    (type a)
    ~(domain: a domain)
    ~(get_state : Analysis_location.local -> a or_top_bottom)
    interferences thread concurrent_writes shared_bases =
  let module Dom = (val domain) in
  match Dom.get MtDomain.Domain.key with
  | None -> () (* Domain disabled, no interference computation *)
  | Some extract ->
    let dom_join s1 s2 = `Value (Dom.join s1 s2) in
    (* Add interferences one by one *)
    let add_to_map acc_map aloc =
      let open TopBottom.Operators in
      let state =
        (* Retrieve state at analysis location *)
        let+ state = get_state aloc in
        let mutexes_status = MtDomain.Domain.mutexes (extract state) in
        let mutexes = MtMutex.Register.locked_mutexes mutexes_status in
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
          | None -> Some (`Value state)
          | Some previous -> Some (Top.join dom_join previous (`Value state))
        in
        MutexesMap.update mutexes update acc_map
    in
    let new_interferences =
      List.fold_left add_to_map MutexesMap.empty concurrent_writes
    in
    let pp_aloc = Analysis_location.Local.pretty in
    Self.debug ~dkey
      "concurrent writes: @[%a@]@.shared bases: @[%a@]@.interferences: @[%a@]@."
      (Pretty_utils.pp_list ~sep:",@ " pp_aloc) concurrent_writes
      Base.Hptset.pretty shared_bases
      (MutexesMap.pretty Dom.pretty) new_interferences;
    (* Add the computed interferences to the table *)
    let Interferences ({ states; structure } as interferences) = interferences in
    match Abstract.Domain.eq_structure structure Dom.structure with
    | None -> structure_mismatch ()
    | Some Eq ->
      ThreadTable.replace states thread new_interferences;
      interferences.shared_bases <- shared_bases


(* Interference injection *)

let applicable (type a) ~(domain : a domain) (interferences : t) (state : a)
  : a or_top_bottom =
  let module Dom = (val domain) in
  let threads, mutexes = match Dom.get MtDomain.Domain.key with
    (* Domain disabled, no information about threads and mutexes *)
    | None -> MtThread.Register.empty, Mutex.Set.empty
    (* Domain enabled *)
    | Some extract ->
      let mt_state = extract state in
      MtDomain.Domain.threads mt_state,
      MtDomain.Domain.mutexes mt_state |> MtMutex.Register.locked_mutexes
  in
  let Interferences { states; structure } = interferences in
  match Abstract.Domain.eq_structure structure Dom.structure with
  | None -> structure_mismatch ()
  | Some Eq ->
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
        match MtThread.Register.find thread threads with
        (* Thread status is uknown, consider that the thread might be running*)
        | None -> true
        (* Thread status is known *)
        | Some status -> MtUtils.Trilean.maybe_true status.running
      in
      let can_thread_interfere = maybe_running && not is_current_thread in
      if can_thread_interfere
      then MutexesMap.fold add state_map acc_state
      else acc_state
    in
    ThreadTable.fold add_thread states `Bottom

let inject (type a) ~(domain : a domain) (state : a) : a =
  let module Dom = (val domain) in
  let interferences = !current in
  let Interferences { shared_bases } = interferences in
  if is_empty interferences
  (* No interferences computed, single threaded analysis *)
  then state
  else begin
    let need_injection =
      match Dom.get MtDomain.Domain.key with
      (* Domain disabled, no interference injection *)
      | None -> false
      (* Domain enabled *)
      | Some extract ->
        let mt_state = extract state in
        let memory = MtDomain.Domain.memory mt_state in
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
      match applicable ~domain interferences state with
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
  end

let is_empty () = is_empty !current
