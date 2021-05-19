(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2021                                               *)
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
open Locations

type taint = {
  (* Over-approximation of the memory locations that are tainted due to a data
     dependency. *)
  locs_data: Zone.t;
  (* Over-approximation of the memory locations that are tainted due to a
     control dependency. *)
  locs_control: Zone.t;
  (* Set of assume statements over a tainted expression. This set is needed to
     implement control-dependency: all left-values appearing in statements whose
     evaluation depends on at least one of the assume expressions is to be
     tainted. *)
  assume_stmts: Stmt.Set.t;
}

let dkey = Value_parameters.register_category "d-taint"

(* Debug key to also include [assume_stmts] in the output of the
   Frama_C_domain_show_each directive. *)
let dkey_debug = Value_parameters.register_category "d-taint-debug"


module LatticeTaint = struct

  let pp_locs_only fmt t =
    Format.fprintf fmt
      "@[<v 2>Locations (data):@ @[<hov>%a@]@]@\n\
       @[<v 2>Locations (control):@ @[<hov>%a@]@]"
      Zone.pretty t.locs_data
      Zone.pretty t.locs_control

  let pp_state fmt t =
    Format.fprintf fmt
      "@[<v 2>Locations (data):@ @[<hov>%a@]@]@\n\
       @[<v 2>Locations (control):@ @[<hov>%a@]@]@\n\
       @[<v 2>Assume statements:@ @[<hov>%a@]@]"
      Zone.pretty t.locs_data
      Zone.pretty t.locs_control
      Stmt.Set.pretty t.assume_stmts

  (* Frama-C "datatype" for type [taint]. *)
  include Datatype.Make_with_collections(struct
      include Datatype.Serializable_undefined

      type t = taint

      let name = "Value.Taint.t"

      let reprs =
        [ { locs_data = List.hd Zone.reprs;
            locs_control = List.hd Zone.reprs;
            assume_stmts = Stmt.Set.empty; } ]

      let structural_descr =
        Structural_descr.t_abstract (* TODO *)

      let compare t1 t2 =
        let c = Zone.compare t1.locs_data t2.locs_data in
        if c <> 0
        then c
        else
          let c = Zone.compare t1.locs_data t2.locs_data in
          if c <> 0
          then c
          else Stmt.Set.compare t1.assume_stmts t2.assume_stmts

      let equal = Datatype.from_compare

      let pretty fmt t =
        if Value_parameters.is_debug_key_enabled dkey_debug
        then pp_state fmt t
        else pp_locs_only fmt t

      let hash t =
        Hashtbl.hash
          (Zone.hash t.locs_data,
           Zone.hash t.locs_control,
           Stmt.Set.hash t.assume_stmts)

      let copy c = c

    end)

  (* Initial state at the start of the computation: nothing is tainted yet. *)
  let empty = {
    locs_data = Zone.bottom;
    locs_control = Zone.bottom;
    assume_stmts = Stmt.Set.empty;
  }

  (* Top state: everything is tainted. *)
  let top = {
    locs_data = Zone.top;
    locs_control = Zone.top;
    assume_stmts = Stmt.Set.empty;
  }

  (* Join: keep pointwise over-approximation. *)
  let join t1 t2 =
    { locs_data = Zone.join t1.locs_data t2.locs_data;
      locs_control = Zone.join t1.locs_control t2.locs_control;
      assume_stmts = Stmt.Set.union t1.assume_stmts t2.assume_stmts; }

  (* The memory locations are finite, so the ascending chain property is
     already verified. We simply use a join. *)
  let widen _ _ t1 t2 = join t1 t2

  let narrow t1 t2 =
    `Value {
      locs_data = Zone.narrow t1.locs_data t2.locs_data;
      locs_control = Zone.narrow t1.locs_control t2.locs_control;
      assume_stmts = Stmt.Set.inter t1.assume_stmts t2.assume_stmts;
    }

  (* Inclusion testing: pointwise, on locs only. *)
  let is_included t1 t2 =
    Zone.is_included t1.locs_data t2.locs_data &&
    Zone.is_included t1.locs_control t2.locs_control

  (* Intersection testing: pointwise, on locs only. *)
  let intersects t e =
    Zone.intersects t.locs_data e ||
    Zone.intersects t.locs_control e

end


module TransferTaint = struct

  let zone_of_taint_annot stmt =
    let zone_of_term t =
      match t.term_node with
      | TLval (TVar { lv_origin = Some vi }, TNoOffset) ->
        Locations.zone_of_varinfo vi
      | _ ->
        (* TODO: Better message. *)
        Value_parameters.not_yet_implemented ~current:true
          "@[The taint domain currently supports only variables.@]"
    in
    match Eva_annotations.get_taint_annot stmt with
    | [] ->
      Zone.bottom
    | [ tt ] ->
      List.fold_left
        (fun zones t -> Zone.join zones (zone_of_term t))
        Zone.bottom
        tt
    | _ ->
      (* No more than one annotation at time. *)
      assert false

  let loc_of_lval valuation lv =
    match valuation.Abstract_domain.find_loc lv with
    | `Value loc -> loc.Eval.loc
    | `Top -> Precise_locs.loc_top

  (* Keeps only active tainted assumes for [stmt]. A tainted assume in [state]
     is considered active on a statement [stmt] whenever there exists a path
     from the tainted assume that not go through [stmt], ie [stmt] is not a
     postdominator for the tainted assume. *)
  let filter_active_tainted_assumes stmt state =
    let kf = Kernel_function.find_englobing_kf stmt in
    let assume_stmts =
      Stmt.Set.filter
        (fun assume_stmt ->
           not (!Db.Postdominators.is_postdominator kf
                  ~opening:assume_stmt ~closing:stmt))
        state.assume_stmts
    in
    { state with assume_stmts }

  (* No update about taint wrt information provided by the other domains. *)
  let update _valuation state = `Value state

  let assign ki lv exp _v valuation state =
    let state =
      match ki with
      | Kglobal ->
        state
      | Kstmt stmt ->
        let to_loc = loc_of_lval valuation in
        let ploc = to_loc lv.Eval.lval in
        let lv_zone =
          let loc = Precise_locs.imprecise_location ploc in
          Locations.enumerate_valid_bits Write loc
        in
        (* Update [state] by considering as tainted the left-values appearing in
           taint annotation, and by keeping only the active tainted assumes. *)
        let annot_zone = zone_of_taint_annot stmt in
        let state =
          { state with locs_data = Zone.join state.locs_data annot_zone }
        in
        let state = filter_active_tainted_assumes stmt state in
        (* Control-dependency: taint the left-value of an assign statement whose
           execution depends on the value of a tainted assume statement. *)
        let state =
          if Stmt.Set.is_empty state.assume_stmts
          then
            (* No active tainted assume statement means that there is no
               control-dependecy that applies on [lv]. *)
            state
          else
            { state with locs_control = Zone.join state.locs_control lv_zone }
        in
        (* Data-dependecy: taint the left-value of an assign statement if
           tainted locations are involved in either the offset part of the
           left-value or the assigned expression. As a special case, a
           left-value is tainted as soon as it appears in a taint annotation. *)
        let is_taint_annotated = Zone.is_included lv_zone annot_zone in
        if is_taint_annotated
        then
          state
        else
          (* Compute data-dependency with [state]: whenever [exp] (or its
             sub-expressions) is tainted, or [lv] is indexed by a tainted memory
             location. *)
          let exp_zone = Value_util.zone_of_expr to_loc exp in
          let lv_indirect_zone =
            Value_util.indirect_zone_of_lval to_loc lv.Eval.lval
          in
          let intersect_state =
            LatticeTaint.intersects state exp_zone ||
            LatticeTaint.intersects state lv_indirect_zone
          in
          if intersect_state
          then { state with locs_data = Zone.join state.locs_data lv_zone }
          else if Precise_locs.cardinal_zero_or_one ploc
          then { state with locs_data = Zone.diff state.locs_data lv_zone }
          else state
    in
    `Value state

  let assume stmt exp _b valuation state =
    let state = filter_active_tainted_assumes stmt state in
    let state =
      let annot_zone = zone_of_taint_annot stmt in
      { state with locs_control = Zone.join state.locs_control annot_zone }
    in
    (* Add [stmt] as assume statement in [state] as soon as [exp] is tainted. *)
    let to_loc = loc_of_lval valuation in
    let exp_zone = Value_util.zone_of_expr to_loc exp in
    let state =
      if LatticeTaint.intersects state exp_zone
      then { state with assume_stmts = Stmt.Set.add stmt state.assume_stmts; }
      else state
    in
    `Value state

  let start_call stmt call _recursion valuation state =
    let state = filter_active_tainted_assumes stmt state in
    let state =
      let annot_zone = zone_of_taint_annot stmt in
      { state with locs_data = Zone.join state.locs_data annot_zone }
    in
    let state =
      (* Add tainted actual parameters in [state]. *)
      let to_loc = loc_of_lval valuation in
      List.fold_left
        (fun s { Eval.concrete; formal; _ } ->
           let concrete_zone = Value_util.zone_of_expr to_loc concrete in
           let formal_zone = Locations.zone_of_varinfo formal in
           if LatticeTaint.intersects state concrete_zone
           then { s with locs_data = Zone.join s.locs_data formal_zone }
           else s)
        state
        call.Eval.arguments
    in
    `Value state

  let finalize_call _stmt _call _recursion ~pre ~post =
    (* Recover assume statements from the [pre] abstract state: we assume the
       control-dependency does not extended beyond the function scope. *)
    `Value { post with assume_stmts = pre.assume_stmts; }

  let show_expr valuation state fmt exp =
    let to_loc = loc_of_lval valuation in
    let exp_zone = Value_util.zone_of_expr to_loc exp in
    Format.fprintf fmt "%B" (LatticeTaint.intersects state exp_zone)

end


module QueriesTaint = struct

  let top_query = `Value (Cvalue.V.top, None), Alarmset.all

  let extract_expr ~oracle:_ _context _state _expr = top_query
  let extract_lval ~oracle:_ _context _state _lv _typ _locs = top_query

  let backward_location _state _lval _typ loc value = `Value (loc, value)

  let reduce_further _state _expr _value =
    [] (* Nothing intelligent to suggest *)

end


module ReuseTaint = struct

  let relate _kf _bases _state = Base.SetLattice.empty
  let filter _kf _kind _bases state = state
  let reuse _kf _bases ~current_input:_ ~previous_output = previous_output

end


module InternalTaint = struct
  type state = taint
  type value = Cvalue.V.t
  type location = Precise_locs.precise_location
  type origin

  include (LatticeTaint: sig
             include Datatype.S_with_collections with type t = state
             include Abstract_domain.Lattice with type state := state
           end)

  include (QueriesTaint: Abstract_domain.Queries
           with type state := state
            and type value := value
            and type location := location
            and type origin := origin)

  include (TransferTaint: Abstract_domain.Transfer
           with type state := state
            and type value := value
            and type location := location
            and type origin := origin)

  include (ReuseTaint: Abstract_domain.Reuse with type t := state)

  let name = "taint"
  let log_category = dkey


  (* Logic. *)

  let logic_assign assign location state =
    let exists_tainted_from state deps =
      let single_from_contents dep =
        match dep.Eval.location with
        | None ->
          false
        | Some location ->
          let loc_zone = Precise_locs.enumerate_valid_bits Read location in
          LatticeTaint.intersects state loc_zone
      in
      List.exists single_from_contents deps
    in
    match assign with
    | None
    | Some ((Eval.Frees _ | Allocates _), _) ->
      state
    | Some (Assigns (_, deps), pre_state) ->
      if exists_tainted_from pre_state deps
      then
        let loc_zone = Precise_locs.enumerate_valid_bits Write location in
        { state with locs_data = Zone.join state.locs_data loc_zone }
      else
        state

  let evaluate_predicate _ _ _ = Alarmset.Unknown
  let reduce_by_predicate _ state _ _ = `Value state


  (* Scoping and Initialization. *)

  let enter_scope _kind _vars state = state

  let leave_scope _kf vars state =
    let remove_unscoped_bases =
      let bases = Base.Set.of_list (List.map Base.of_varinfo vars) in
      Zone.filter_base (fun b -> not (Base.Set.mem b bases))
    in
    { state with
      locs_data = remove_unscoped_bases state.locs_data;
      locs_control = remove_unscoped_bases state.locs_control; }


  (* Initial state: initializers are singletons, so we store nothing. *)
  let empty () = LatticeTaint.empty
  let initialize_variable _ _ ~initialized:_ _ state = state
  let initialize_variable_using_type _ _ state  = state


  (* Misc. *)

  let enter_loop _ state = state
  let incr_loop_counter _ state = state
  let leave_loop _ state = state

  let storage () = true

end


include Domain_builder.Complete (InternalTaint)
