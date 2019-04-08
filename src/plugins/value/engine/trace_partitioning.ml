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
open Partition

module Make
    (Abstract: Abstractions.Eva)
    (Transfer : Transfer_stmt.S with type state = Abstract.Dom.t)
    (Kf : sig val kf: kernel_function end) =
struct
  module Parameters = Partitioning_parameters.Make (Kf)

  open Kf
  open Parameters

  module Domain = Abstract.Dom

  module Index = Partitioning.Make (Domain)
  module Flow = Partition.MakeFlow (Abstract)

  type state = Domain.t

  type store = {
    rationing: Partition.rationing;
    flow_actions : action list;
    store_stmt : stmt option;
    store_index : Index.t;
    mutable store_partition : state partition;
    mutable store_size : int;
  }

  type flow = {
    mutable flow_states : Flow.t;
  }

  type tank = {
    mutable tank_states : state partition;
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
    let limit, merge, flow_actions = match stmt with
      | None -> max_int, false, []
      | Some stmt -> slevel stmt, merge stmt, flow_actions stmt
    in
    let rationing = Partition.new_rationing ~limit ~merge in
    {
      rationing; flow_actions;
      store_stmt = stmt;
      store_index = Index.empty ();
      store_partition = Partition.empty;
      store_size = 0;
    }

  let empty_flow () : flow =
    { flow_states = Flow.empty }

  let empty_tank () : tank =
    { tank_states = Partition.empty }

  let empty_widening ~(stmt : stmt option) : widening =
    {
      widening_stmt = Extlib.opt_conv Cil.invalidStmt stmt;
      widening_partition = Partition.empty;
    }

  let initial_tank (states : state list) : tank =
    let flow = Flow.initial states in
    (* Split the initial partition according to the global split seetings *)
    let states = List.fold_left Flow.transfer_keys flow universal_splits in
    { tank_states = Flow.to_partition states }


  (* Pretty printing *)

  let pretty_store (fmt : Format.formatter) (s : store) : unit =
    Partition.iter (fun _key state -> Domain.pretty fmt state) s.store_partition

  let pretty_flow (fmt : Format.formatter) (p : flow) =
    Flow.iter (Domain.pretty fmt) p.flow_states


  (* Accessors *)

  let expanded (s : store) : state list =
    Partition.to_list s.store_partition

  let smashed (s : store) : state or_bottom =
    match expanded s with
    | [] -> `Bottom
    | v1 :: l -> `Value (List.fold_left Domain.join v1 l)

  let contents (f : flow) : state list =
    Flow.to_list f.flow_states

  let is_empty_store (s : store) : bool =
    Partition.is_empty s.store_partition

  let is_empty_flow (f : flow) : bool =
    Flow.is_empty f.flow_states

  let is_empty_tank (t : tank) : bool =
    Partition.is_empty t.tank_states

  let store_size (s : store) : int =
    s.store_size

  let flow_size (f : flow) : int =
    Flow.size f.flow_states

  let tank_size (t : tank) : int =
    Partition.size t.tank_states


  (* Partition transfer functions *)

  let transfer_action p action =
    p.flow_states <- Flow.transfer_keys p.flow_states action

  let enter_loop (p : flow) (i : stmt) : unit =
    transfer_action p (Enter_loop (unroll i))

  let leave_loop (p : flow) (_i : stmt) : unit =
    transfer_action p Leave_loop

  let next_loop_iteration (p : flow) (_i : stmt) : unit =
    transfer_action p Incr_loop

  let empty_rationing = new_rationing ~limit:0 ~merge:false

  let split_return (flow : flow) (return_exp : exp option) : unit =
    let strategy = Split_return.kf_strategy kf in
    if strategy <> Split_strategy.FullSplit
    then
      let apply action =
        let f = Flow.transfer_keys flow.flow_states action in
        flow.flow_states <- Flow.join_duplicate_keys f
      in
      match Split_return.kf_strategy kf with
      (* SplitAuto already transformed into SplitEqList. *)
      | Split_strategy.FullSplit | Split_strategy.SplitAuto -> assert false
      | Split_strategy.NoSplit -> apply (Ration empty_rationing)
      | Split_strategy.SplitEqList i ->
        match return_exp with
        | None -> apply (Ration empty_rationing)
        | Some return_exp ->
          if Cil.isIntegralOrPointerType (Cil.typeOf return_exp)
          then apply (Restrict (return_exp, i))
          else apply (Ration empty_rationing)

  (* Reset state (for hierchical convergence) *)

  let reset_store (s : store) : unit =
    let is_eternal key _state = not (Key.exceed_rationing key) in
    s.store_partition <- Partition.filter is_eternal s.store_partition

  let reset_flow (f : flow) : unit =
    f.flow_states <- Flow.empty

  let reset_tank (t : tank) : unit =
    t.tank_states <- Partition.empty

  let reset_widening (w : widening) : unit =
    w.widening_partition <- Partition.empty

  let reset_widening_counter (w : widening) : unit =
    let reset w =
      { w with widening_counter = max w.widening_counter (widening_period - 1) }
    in
    w.widening_partition <- Partition.map reset w.widening_partition


  (* Operators *)

  let drain (t : tank) : flow =
    let flow_states = Flow.of_partition t.tank_states in
    t.tank_states <- Partition.empty;
    { flow_states }

  let fill ~(into : tank) (f : flow) : unit =
    let erase _key dest src =
      if Extlib.has_some src
      then src
      else dest
    in
    let new_states = Flow.to_partition f.flow_states in
    into.tank_states <- Partition.merge erase into.tank_states new_states

  let transfer (f : state -> state list) (p : flow) : unit =
    p.flow_states <- Flow.transfer_states f p.flow_states

  let join (sources : (branch*flow) list) (dest : store) : flow =
    let is_loop_head =
      match dest.store_stmt with
      | Some {skind=Cil_types.Loop _} -> true
      | _ -> false
    in
    (* Get every source flow *)
    let sources_states =
      match sources with
      | [(_,p)] -> [p.flow_states]
      | sources ->
        (* Several branches -> partition according to the incoming branch *)
        let get (b,p) =
          Flow.transfer_keys p.flow_states (Branch (b,history_size))
        in
        List.map get sources
    in
    (* Merge incomming flows *)
    let flow_states =
      List.fold_left Flow.union Flow.empty sources_states
    in
    (* Handle ration stamps *)
    dest.store_size <- dest.store_size + Flow.size flow_states;
    let rationing_action = Ration dest.rationing in
    (* Handle Split / Merge operations *)
    let flow_actions = Update_dynamic_splits :: dest.flow_actions in
    (* Execute actions *)
    let actions = rationing_action :: flow_actions in
    let flow_states =
      List.fold_left Flow.transfer_keys flow_states actions
    in
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
    let flow = Flow.join_duplicate_keys flow_states in
    let flow = Flow.filter_map update flow in
    { flow_states = flow }


  let widen (w : widening) (f : flow) : bool =
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
        (* Propagated state decreases, stop propagating *)
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
        (* The key is not in the widening state; add the state if slevel is
           exceeded *)
        if Key.exceed_rationing key then
          update key {
            widened_state = None;
            previous_state = curr;
            widening_counter = widening_delay - 1;
          };
        Some curr
    in
    let flow = Flow.join_duplicate_keys f.flow_states in
    let flow = Flow.filter_map widen_one flow in
    f.flow_states <- flow;
    Flow.is_empty f.flow_states
end
