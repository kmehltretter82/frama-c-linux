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

open Cil_types
open Cil_datatype
open MtCil
open MtMemory.Types
open MtLib
open MtIds


(* -------------------------------------------------------------------------- *)
(* --- Variable access kind                                               --- *)
(* -------------------------------------------------------------------------- *)


type rw = Read | Write of Locations.location

module RW = Datatype.Make(
  struct
    include Datatype.Serializable_undefined
    type t = rw = Read | Write of Locations.location
    let name = "rw"
    let reprs = [Read]
    let equal rw1 rw2 = match rw1, rw2 with
      | Read, Read -> true
      | Write l1, Write l2 -> Locations.Location.equal l1 l2
      | Read, Write _ | Write _, Read -> false
    let compare rw1 rw2 = match rw1, rw2 with
      | Read, Read -> 0
      | Write l1, Write l2 -> Locations.Location.compare l1 l2
      | Read, Write _ -> -1
      | Write _, Read -> 1
    let hash = function
      | Read -> 17
      | Write l -> 39 + Locations.Location.hash l
    let pretty fmt rw = Format.fprintf fmt "%s"
        (match rw with
         | Read -> "read"
         | Write _ -> "write"
        )
  end)


(* -------------------------------------------------------------------------- *)
(* --- Multi-threading events                                             --- *)
(* -------------------------------------------------------------------------- *)

type event =
  | CreateThread of id
  | StartThread of id
  | SuspendThread of id
  | CancelThread of id
  | ThreadExit of value
  | MutexLock of id
  | MutexRelease of id
  | CreateQueue of id * int option
  | SendMsg of id * (slice * int)
  | ReceiveMsg of id * pointer * int
  | VarAccess of rw * Locations.Zone.t
  | Dummy of string * value list

module Event = struct
  type t = event

  let pretty fmt = function
    | CreateThread id -> Format.fprintf fmt "Create thread %a" Id.pretty id
    | StartThread id -> Format.fprintf fmt "Start thread %a" Id.pretty id
    | SuspendThread id -> Format.fprintf fmt "Suspend thread %a" Id.pretty id
    | CancelThread id -> Format.fprintf fmt "Cancel thread %a" Id.pretty id
    | ThreadExit v -> Format.fprintf fmt "Thread exit, with code %a"
                        Cvalue.V.pretty v
    | MutexLock id -> Format.fprintf fmt "Lock %a" Id.pretty id
    | MutexRelease id -> Format.fprintf fmt "Release %a" Id.pretty id
    | CreateQueue (id, s) ->
      Format.fprintf fmt "Creating queue %a%a" Id.pretty id
        (fun fmt -> function None -> ()
                           | Some s -> Format.fprintf fmt " (size %d)" s) s
    | SendMsg (id, (v, _s)) -> Format.fprintf fmt
                                 "Sending@ message@ on %a,@ content@ %a"
                                 Id.pretty id MtMemory.pretty_slice v
    | ReceiveMsg (id, loc, size) -> Format.fprintf fmt
                                      "Receiving@ message@ on %a,@ max size %d,@ stored in %a."
                                      Id.pretty id size Pointer.pretty loc
    | VarAccess (rw, loc) ->
      Format.fprintf fmt "Var access@ %a@ of %a"
        RW.pretty rw Locations.Zone.pretty loc
    | Dummy (s, l) ->
      Format.fprintf fmt "%s %a" s
        (Pretty_utils.pp_list ~sep:"@ " Cvalue.V.pretty) l

  let equal a1 a2 = match a1, a2 with
    | CreateThread i1, CreateThread i2
    | StartThread i1, StartThread i2
    | SuspendThread i1, SuspendThread i2
    | CancelThread i1, CancelThread i2
    | MutexLock i1, MutexLock i2
    | MutexRelease i1, MutexRelease i2 -> Id.equal i1 i2
    | CreateQueue (i1, s1), CreateQueue (i2, s2) ->
      Id.equal i1 i2 && s1 = s2
    | SendMsg (i1, (v1, s1)), SendMsg (i2, (v2, s2)) ->
      Id.equal i1 i2 && Cvalue.V_Offsetmap.equal v1 v2 && s1 = s2
    | ReceiveMsg (i1, l1, s1), ReceiveMsg (i2, l2, s2) ->
      s1 = s2 && Id.equal i1 i2 && Pointer.equal l1 l2
    | VarAccess (rw1, z1), VarAccess (rw2, z2) ->
      RW.equal rw1 rw2 && Locations.Zone.equal z1 z2
    | (CreateThread _ | StartThread _ | SuspendThread _ | CancelThread _
      | ThreadExit _
      | MutexLock _ | MutexRelease _ | CreateQueue _
      | SendMsg _ | ReceiveMsg _ | VarAccess _ | Dummy _), _ ->
      false


  let compare a1 a2 = match a1, a2 with
    | CreateThread i1, CreateThread i2
    | StartThread i1, StartThread i2
    | SuspendThread i1, SuspendThread i2
    | CancelThread i1, CancelThread i2
    | MutexLock i1, MutexLock i2
    | MutexRelease i1, MutexRelease i2 -> Id.compare i1 i2
    | ThreadExit v1, ThreadExit v2 -> Cvalue.V.compare v1 v2
    | CreateQueue (i1, s1), CreateQueue (i2, s2) ->
      comp compare s1 s2 Id.compare i1 i2
    | SendMsg (i1, (v1, s1)), SendMsg (i2, (v2, s2)) ->
      comp Stdlib.compare s1 s2
        (comp Cvalue.V_Offsetmap.compare v1 v2 Id.compare)
        i1 i2
    | ReceiveMsg (i1, l1, s1), ReceiveMsg (i2, l2, s2) ->
      comp Stdlib.compare s1 s2
        (comp Pointer.compare l1 l2 Id.compare)
        i1 i2
    | VarAccess (rw1, z1), VarAccess (rw2, z2) ->
      comp RW.compare rw1 rw2 Locations.Zone.compare z1 z2
    | Dummy (s1, l1), Dummy (s2, l2) ->
      comp String.compare s1 s2
        (Extlib.list_compare Cvalue.V.compare) l1 l2
    | (CreateThread _ | StartThread _ | SuspendThread _ | CancelThread _
      | ThreadExit _
      | MutexLock _ | MutexRelease _ | CreateQueue _
      | SendMsg _ | ReceiveMsg _ | VarAccess _ | Dummy _), _ ->
      MtLib.compare_tag a1 a2

  let hash = function
    | CreateThread i -> Hashtbl.hash (Id.hash i, 0)
    | CancelThread i -> Hashtbl.hash (Id.hash i, 1)
    | MutexLock i -> Hashtbl.hash (Id.hash i, 2)
    | MutexRelease i -> Hashtbl.hash (Id.hash i, 3)
    | CreateQueue (i, s) -> Hashtbl.hash (Id.hash i, s, 4)
    | SendMsg (i, (v, s)) ->
      Hashtbl.hash (Id.hash i, Cvalue.V_Offsetmap.hash v, s, 5)
    | ReceiveMsg (i, l, size) ->
      Hashtbl.hash (Id.hash i, Pointer.hash l, size, 6)
    | VarAccess (rw, z) -> Hashtbl.hash (RW.hash rw, Locations.Zone.hash z, 7)
    | ThreadExit v -> Hashtbl.hash (Cvalue.V.hash v, 8)
    | Dummy (s, l) -> Hashtbl.hash (s, List.map Cvalue.V.hash l, 9)
    | StartThread i -> Hashtbl.hash (Id.hash i, 10)
    | SuspendThread i -> Hashtbl.hash (Id.hash i, 11)

end

module EventsSet = struct
  include Set.Make(Event)

  let threads_created s =
    fold (fun act l -> match act with
        | CreateThread id -> id :: l
        | _ -> l) s []

  let pretty ?(sep=("@ ": (_, _, _, _, _, _) format6)) () fmt =
    Pretty_utils.pp_iter ~pre:"" ~suf:"" ~sep iter Event.pretty fmt

end
type events_set = EventsSet.t


(* -------------------------------------------------------------------------- *)
(* --- Execution traces                                                   --- *)
(* -------------------------------------------------------------------------- *)

module Trace =
struct

  module TriesStacks = Trie.Make(Map.Make(StackElt))

  type data = {
    trace_events: events_set;
    trace_states: state Stmt.Map.t;
    trace_states_after: state Stmt.Map.t;
  }

  let join_data d1 d2 = {
    trace_events = EventsSet.union d1.trace_events d2.trace_events;
    trace_states = merge_map_functions_states d1.trace_states d2.trace_states;
    trace_states_after =
      merge_map_functions_states d1.trace_states_after d2.trace_states_after;
  }

  type t = data TriesStacks.t

  let empty = TriesStacks.empty

  let is_empty = TriesStacks.is_empty

  let default = {
    trace_events = EventsSet.empty;
    trace_states = Stmt.Map.empty;
    trace_states_after = Stmt.Map.empty;
  }

  let union = TriesStacks.union (fun _ d1 d2 -> Some (join_data d1 d2))

  let add_prefix = TriesStacks.add_prefix

  let add_aux f (trie: t) (stack : stack) =
    let cur =
      try TriesStacks.find stack trie
      with Not_found -> default
    in
    TriesStacks.add stack (f cur) trie

  let add_event t s evt =
    add_aux
      (fun d -> { d with trace_events = EventsSet.add evt d.trace_events}) t [s]

  let add_states t ~before ~after =
    add_aux
      (fun d -> { d with
                  trace_states = merge_map_non_map_functions_states d.trace_states before;
                  trace_states_after =
                    merge_map_non_map_functions_states d.trace_states_after after;
                })
      t []

  let subtrace_at_call trie call =
    try TriesStacks.select_prefix call trie
    with Not_found -> empty

  let no_deep_call trie =
    (* this is true if the trie only contains a singleton key of size 1 *)
    TriesStacks.prefixes_seq trie () = Seq.Nil


  let find_at_stmt trie stmt =
    TriesStacks.prefixes_seq trie
    |> Seq.filter
      (fun ((_,kinstr), _) ->
         match kinstr with
         | Kglobal -> false
         | Kstmt s -> Cil_datatype.Stmt.equal s stmt)
    |> List.of_seq


  let at_root trie =
    TriesStacks.find_opt [] trie

  let at_call trie call =
    try Some (TriesStacks.find [call] trie)
    with Not_found -> None

  let fold (trie : t) f =
    TriesStacks.fold
      (fun stack d -> EventsSet.fold (f stack) d.trace_events) trie

  let fold' t f = fold t (fun _ -> f)

  let iter (trie : t) f =
    TriesStacks.iter
      (fun stack d -> EventsSet.iter (f stack) d.trace_events) trie

  let iter' t f = iter t (fun _ -> f)

  let exists (trie : t) f =
    TriesStacks.exists
      (fun stack d -> EventsSet.exists (f stack) d.trace_events) trie

  let find_events f t =
    fold' t (fun evt acc -> if f evt then EventsSet.add evt acc else acc)
      EventsSet.empty


  let pretty fmt t =
    Format.fprintf fmt "@[<v>";
    TriesStacks.iter
      (fun stack d ->
         Format.fprintf fmt
           "stack:@ %a@ actions:@[%a@]@ @ "
           Stack.pretty stack (EventsSet.pretty ()) d.trace_events) t;
    Format.fprintf fmt "@]@.";
end


(* -------------------------------------------------------------------------- *)
(* --- Live threads/taken mutexes at a given point of execution           --- *)
(* -------------------------------------------------------------------------- *)

type presence_flag = NotPresent | Present | MaybePresent

module PresenceFlag = struct

  include Datatype.Make(
    struct
      include Datatype.Serializable_undefined
      type t = presence_flag
      let name = "MtTypes.presence_flag"
      let reprs = [NotPresent; Present; MaybePresent]
      let equal : t -> t -> _ = (=)
      let compare : t -> t -> int = Stdlib.compare
      let hash : t -> _ = Hashtbl.hash
    end)

  let combine p1 p2 = match p1, p2 with
    | Present, Present -> Present
    | NotPresent, NotPresent -> NotPresent
    | _ -> MaybePresent

  let fast_equal = equal

end



module Presence = struct

  (* Implementation of maps on ids with hashing information. Invariant:
     we never store [NotPresent] inside the table, as it is the default
     value, and this introduces non-canonicity problems. (This is not
     disastrous per se, but this also implies that [equal m1 m2] does not
     imply [hash m1 = hash m2], a bad idea...) *)
  module M = Rangemap.Make(Id)(PresenceFlag)

  type t = M.t

  let pretty_with_flag fmt (id, p) = match p with
    | NotPresent -> ()
    | MaybePresent -> Format.fprintf fmt "(?)%a" Id.pretty id
    | Present -> Format.fprintf fmt "%a" Id.pretty id

  let pretty = Pretty_utils.pp_iter ~pre:"" ~suf:"" ~sep:"@ "
      (fun f -> M.iter (fun k v -> f (k, v))) pretty_with_flag

  let equal = M.equal
  let compare = M.compare
  let hash = M.hash

  let find (p : t) id =
    try M.find id p
    with Not_found -> NotPresent

  let add k v m =
    match v with
    | NotPresent -> M.remove k m
    | _ -> M.add k v m

  let conv = function
    | None -> NotPresent
    | Some v -> v

  let combine_aux f =
    let aux p1 p2 =
      match f (conv p1) (conv p2) with
      | NotPresent -> None (* Make sure not to store NotPresent *)
      | p -> Some p
    in
    M.merge (fun _ -> aux)


  let combine = combine_aux PresenceFlag.combine

  let empty = M.empty

  let is_empty = M.is_empty

  let only_present m =
    let aux id flag acc =
      if flag = Present then Id.Set.add id acc else acc
    in
    M.fold aux m Id.Set.empty


end

type presence = Presence.t
