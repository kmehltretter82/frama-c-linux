(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2019                                               *)
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
open Bottom.Type
open State_partitioning
open Partition


module Make
    (Domain : Abstract_domain.External)
    (Transfer : Transfer_stmt.S with type state = Domain.t)
    (Kf : Kf) =
struct
  module Parameters = Partitioning_parameters.Make (Kf)

  open Kf
  open Parameters

  (* Add the split function to the domain *)
  module Domain =
  struct
    exception Cant_split = Transfer.Cant_split
    let split = Transfer.split_by_value

    include Domain
  end

  module Index = Partitioning.Make (Domain)
  module Partition = Partition.Make (Domain)

  type state = Domain.t

  type store = {
    size_limit : int;
    merge : bool;
    flow_actions : action list;
    store_stmt : stmt option;
    store_index : Index.t;
    mutable store_partition : state partition;
    mutable store_size : int;
  }

  type propagation = {
    mutable partition : state partition;
  }

  type widening_state = {
    widened_state : state option;
    previous_state : state;
    widening_counter : int;
  }

  type widening = {
    widening_stmt : stmt;
    mutable widening_partition : widening_state partition;
  }

  (* Constructors *)

  let empty_store ~(stmt : stmt option) : store =
    let size_limit, merge, flow_actions = match stmt with
      | None -> max_int, false, []
      | Some stmt -> slevel stmt, merge stmt, flow_actions stmt
    in
    {
      size_limit; merge; flow_actions;
      store_stmt = stmt;
      store_index = Index.empty ();
      store_partition = Partition.empty;
      store_size = 0;
    }

  let empty_propagation () : propagation =
    { partition = Partition.empty }

  let empty_widening ~(stmt : stmt option) : widening =
    {
      widening_stmt = Extlib.opt_conv Cil.invalidStmt stmt;
      widening_partition = Partition.empty;
    }

  let initial_propagation (states : state list) : propagation =
    let partition = Partition.initial states in
    (* Split the initial partition according to the global split seetings *)
    let split partition lval =
      Partition.transfer_keys partition (Dynamic_split lval)
    in
    let partition = List.fold_left split partition universal_splits in
    { partition }


  (* Pretty printing *)

  let pretty_store (fmt : Format.formatter) (s : store) : unit =
    Partition.iter (Domain.pretty fmt) s.store_partition

  let pretty_propagation (fmt : Format.formatter) (p : propagation) =
    Partition.iter (Domain.pretty fmt) p.partition


  (* Accessors *)

  let expanded (s : store) : state list =
    Partition.to_list s.store_partition

  let smashed (s : store) : state or_bottom =
    match expanded s with
    | [] -> `Bottom
    | v1 :: l -> `Value (List.fold_left Domain.join v1 l)

  let is_empty_store (s : store) : bool =
    Partition.is_empty s.store_partition

  let is_empty_propagation (p : propagation) : bool =
    Partition.is_empty p.partition

  let store_size (s : store) : int =
    s.store_size

  let propagation_size (p : propagation) : int =
    Partition.size p.partition


  (* Partition transfer functions *)

  let enter_loop (p : propagation) (_i : loop) =
    p.partition <- Partition.transfer_keys p.partition Enter_loop

  let leave_loop (p : propagation) (_i : loop) =
    p.partition <- Partition.transfer_keys p.partition Leave_loop

  let next_loop_iteration (p : propagation) (i : loop) =
    let limit = unroll i in
    p.partition <- Partition.transfer_keys p.partition (Incr_loop limit)


  (* Reset state (for hierchical convergence) *)

  let reset_store (s : store) : unit =
    let is_eternal key =
      key.ration_stamp <> None
    in
    s.store_partition <- Partition.filter_keys is_eternal s.store_partition

  let reset_propagation (p : propagation) : unit =
    p.partition <- Partition.empty

  let reset_widening (w : widening) : unit =
    w.widening_partition <- Partition.empty

  let reset_widening_counter (w : widening) : unit =
    let reset w =
      { w with widening_counter = max w.widening_counter (widening_period - 1) }
    in
    w.widening_partition <- Partition.map_states reset w.widening_partition


  (* Operators *)

  let clear_propagation (p : propagation) : unit =
    p.partition <- Partition.empty

  let transfer (f : state list -> state list) (p : propagation) : unit =
    p.partition <- Partition.transfer_states (fun s -> f [s]) p.partition

  let merge ~(into : propagation) (source : propagation) : unit =
    (* TODO: state the precondition for this to be correct *)
    let merge_two dest src = (* Erase the destination *)
      if Extlib.has_some src
      then src
      else dest
    in
    into.partition <- Partition.merge merge_two into.partition source.partition

  let join (sources : (branch*propagation) list) (dest : store)
      : propagation =
    let is_loop_head =
      match dest.store_stmt with
      | Some {skind=Cil_types.Loop _} -> true
      | _ -> false
    in
    let current_ration = ref dest.store_size in
    (* Update states counters *)
    let count acc (_b,p) =
      acc + Partition.size p.partition
    in
    dest.store_size <- List.fold_left count dest.store_size sources;
    (* Get every source propagation *)
    let source_partitions =
      match sources with
      | [(_,p)] -> [p.partition]
      | sources ->
        (* Several branches ; partition according to the incoming branch *)
        let get (b,p) =
          Partition.transfer_keys p.partition (Branch (b,history_size))
        in
        List.map get sources
    in
    (* Handle ration stamps *)
    let slevel_exceeded = dest.store_size > dest.size_limit in
    let rationing =
      if slevel_exceeded then
        (* No more slevel, no more ration tickets *)
        fun p -> Partition.transfer_keys p (Ration_merge None)
      else if dest.merge then
        (* Merge / Merge after loop : a unique ration stamp for all *)
        fun p -> Partition.transfer_keys p (Ration_merge (Some !current_ration))
      else begin fun p ->
        (* Attribute a ration stamp to each individual state *)
        let p = Partition.transfer_keys p (Ration !current_ration) in
        current_ration := !current_ration + Partition.size p;
        p
      end
    in
    let source_partitions = List.map rationing source_partitions in
    (* Handle Split / Merge operations *)
    let do_flow_actions partition =
      let actions =
        dest.flow_actions @ [Update_dynamic_splits ; Transfer_merge]
      in
      List.fold_left Partition.transfer_keys partition actions
    in
    let source_partitions = List.map do_flow_actions source_partitions in
    (* Merge incomming propagations *)
    let union = Partition.union Domain.join in
    let partition = List.fold_left union Partition.empty source_partitions in
    (* Add states to the store but filter out already propagated states *)
    let update key current_state =
      (* Inclusion test *)
      let state =
        try
          let previous_state = Partition.find key dest.store_partition in
          if Domain.is_included current_state previous_state then
            (* The current state is included in the previous; stop *)
            None
          else begin
            (* Propagate the join of the two states *)
            if is_loop_head then
              Value_parameters.feedback ~level:1 ~once:true ~current:true
                "starting to merge loop iterations";
            Some (Domain.join previous_state current_state)
          end
        with
          (* There is no previous state, propagate normally *)
          Not_found -> Some current_state
      in
      (* Add the propagated state to the store *)
      let add s =
        dest.store_partition <- Partition.replace key s dest.store_partition;
      in
      Extlib.may add state;
      (* Filter out already propagated states *)
      Extlib.opt_filter (fun s -> Index.add s dest.store_index) state
    in
    let partition = Partition.map_filter update partition in
    { partition }


  let widen (_s : store) (w : widening) (p : propagation) : bool =
    let stmt = w.widening_stmt in
    (* Auxiliary function to update the result *)
    let update key widening_state =
      w.widening_partition <-
        Partition.replace key widening_state w.widening_partition
    in
    (* Apply widening to each leaf *)
    let widen_one key curr =
      try
        (* Search for an already existing widening state *)
        let wstate = Partition.find key w.widening_partition in
        (* Update the widening state *)
        update key {
          wstate with
          previous_state = curr;
          widening_counter = wstate.widening_counter - 1
        };
        (* Propagated state decreases, stop to propagate *)
        if Domain.is_included curr wstate.previous_state then
          None
        (* Widening is delayed *)
        else if wstate.widening_counter > 0 then begin
          Some curr
        (* Apply widening *)
        end else begin
          Value_parameters.feedback ~level:1 ~once:true ~current:true
            ~dkey:Value_parameters.dkey_widening
            "applying a widening at this point";
          (* We join the previous widening state with the previous iteration
             state so as to allow the intermediate(s) iteration(s) (between
             two widenings) to stabilize at least a part of the state. *)
          let prev = match wstate.widened_state with
          | Some v -> Domain.join wstate.previous_state v
          | None -> wstate.previous_state
          in
          let next = Domain.widen kf stmt prev (Domain.join prev curr) in
          update key {
            previous_state = next;
            widened_state = Some next;
            widening_counter = widening_period - 1;
          };
          Some next
        end
      with Not_found ->
        (* The key is not in the widening state; add it if slevel is not
           exceeded *)
        if key.ration_stamp = None then
          update key {
              widened_state = None;
              previous_state = curr;
              widening_counter = widening_delay - 1;
          };
        Some curr
    in
    p.partition <- Partition.map_filter widen_one p.partition;
    Partition.is_empty p.partition
end
