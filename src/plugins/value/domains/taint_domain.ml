(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2020                                               *)
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
  (* Over-approximation of the memory locations that are tainted. *)
  locs: Zone.t;
  (* Set of assume statements over a tainted expression. This set is needed to
     implement control-dependency: all left-values appearing in statements whose
     evaluation depends on at least one of the assume expressions is to be
     tainted. *)
  assume_stmts: Stmt.Set.t;
}

(* Set to true for pretty-printing also [assume_stmts] on
   Frama_C_domain_show_each directive. *)
let debug = false


module LatticeTaint = struct

  let pp_locs_only fmt t =
    Format.fprintf fmt "@[<hov>%a@]" Zone.pretty t.locs

  let pp_state fmt t =
    Format.fprintf fmt
      "@[<v 2>Locations:@ @[<hov>%a@]@]@.\
       @[<v 2>Assume statements:@ @[<hov>%a@]@]"
      Zone.pretty t.locs
      Stmt.Set.pretty t.assume_stmts

  (* Frama-C "datatype" for type [taint]. *)
  include Datatype.Make_with_collections(struct
      include Datatype.Serializable_undefined

      type t = taint

      let name = "Value.Taint.t"

      let reprs =
        [ { locs = List.hd Zone.reprs;
            assume_stmts = Stmt.Set.empty; } ]

      let structural_descr =
        Structural_descr.t_abstract (* TODO *)

      let compare t1 t2 =
        let c = Zone.compare t1.locs t2.locs in
        if c <> 0
        then c
        else Stmt.Set.compare t1.assume_stmts t2.assume_stmts

      let equal = Datatype.from_compare

      let pretty fmt t =
        if debug
        then pp_state fmt t
        else pp_locs_only fmt t

      let hash t =
        Hashtbl.hash
          (Zone.hash t.locs,
           Stmt.Set.hash t.assume_stmts)

      let copy c = c

    end)

  (* Initial state at the start of the computation: nothing is tainted yet. *)
  let empty = {
    locs = Zone.bottom;
    assume_stmts = Stmt.Set.empty;
  }

  (* Top state: everything is tainted. *)
  let top = {
    locs = Zone.top;
    assume_stmts = Stmt.Set.empty;
  }

  (* Join: keep pointwise over-approximation. *)
  let join t1 t2 =
    { locs = Zone.join t1.locs t2.locs;
      assume_stmts = Stmt.Set.union t1.assume_stmts t2.assume_stmts; }

  (* Add zone to state. *)
  let add t e =
    { t with locs = Zone.join t.locs e; }

  (* Remove zone from state. *)
  let remove t e =
    { t with locs = Zone.diff t.locs e; }

  (* The memory locations are finite, so the ascending chain property is
     already verified. We simply use a join. *)
  let widen _ _ t1 t2 = join t1 t2

  let narrow t1 t2 =
    `Value {
      locs = Zone.narrow t1.locs t2.locs;
      assume_stmts = Stmt.Set.inter t1.assume_stmts t2.assume_stmts;
    }

  (* Inclusion testing: pointwise, on locs only. *)
  let is_included t1 t2 =
    Zone.is_included t1.locs t2.locs

  (* Intersection testing: pointwise, on locs only. *)
  let intersects t e =
    Zone.intersects t.locs e

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

  (* Compute whether [stmt] is control-dependent of a tainted assume statement
     in [state]: according to the control-flow graph, if there exists an assume
     statement for which among its successors there exists one that cannot reach
     [stmt], then the evaluation of [stmt] depends on the tainted assumption
     expression. *)
  let is_under_tainted_assume state stmt =
    let kf = Kernel_function.find_englobing_kf stmt in
    Stmt.Set.exists
      (fun assume_stmt ->
         List.exists
           (fun assume_stmt_succ ->
              not (Stmts_graph.stmt_can_reach kf assume_stmt_succ stmt))
           assume_stmt.succs)
      state.assume_stmts

  (* No update about taint wrt information provided by the other domains. *)
  let update _valuation state = `Value state

  let assign ki lv exp _v valuation state =
    let state =
      match ki with
      | Kglobal ->
        state
      | Kstmt stmt ->
        let state = LatticeTaint.add state (zone_of_taint_annot stmt) in
        let to_loc = loc_of_lval valuation in
        let lv_zone =
          Value_util.(zone_of_expr to_loc (lval_to_exp lv.Eval.lval))
        in
        if is_under_tainted_assume state stmt
        then
          (* Taint [lv] as it appears in [stmt], which is control-dependent of a
             tainted assume statement in [state]. *)
          LatticeTaint.add state lv_zone
        else
          (* [stmt] has no control-dependency with [state]: reset [state]'s
             assume statements as no longer valid. *)
          let state = { state with assume_stmts = Stmt.Set.empty; } in
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
          then LatticeTaint.add state lv_zone
          else LatticeTaint.remove state lv_zone
    in
    `Value state

  let assume stmt exp _b valuation state =
    let state = LatticeTaint.add state (zone_of_taint_annot stmt) in
    (* Add [stmt] as assume statement in [state] as soon as [exp] is tainted. *)
    let to_loc = loc_of_lval valuation in
    let exp_zone = Value_util.zone_of_expr to_loc exp in
    let state =
      if LatticeTaint.intersects state exp_zone
      then { state with assume_stmts = Stmt.Set.add stmt state.assume_stmts; }
      else state
    in
    `Value state

  let start_call stmt call valuation state =
    let state = LatticeTaint.add state (zone_of_taint_annot stmt) in
    let state =
      (* Add tainted actual parameters in [state]. *)
      let to_loc = loc_of_lval valuation in
      List.fold_left
        (fun s { Eval.concrete; formal; _ } ->
           let concrete_zone = Value_util.zone_of_expr to_loc concrete in
           let formal_zone = Locations.zone_of_varinfo formal in
           if LatticeTaint.intersects state concrete_zone
           then LatticeTaint.add s formal_zone
           else s)
        state
        call.Eval.arguments
    in
    `Value state

  let finalize_call _stmt _call ~pre ~post =
    (* Recover assume statements from the [pre] abstract state: we assume the
       control-dependency does not extended beyond the function scope. *)
    let state = { post with assume_stmts = pre.assume_stmts } in
    `Value state

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
  let log_category = Value_parameters.register_category "d-taint"


  (* Logic. *)

  let logic_assign _assign _location _state = top
  let evaluate_predicate _ _ _ = Alarmset.Unknown
  let reduce_by_predicate _ state _ _ = `Value state


  (* Scoping and Initialization. *)

  let enter_scope _kind _vars state = state

  let leave_scope _kf vars state =
    let remove_unscoped_bases =
      let bases =
        List.fold_left
          (fun acc v -> Base.Set.add (Base.of_varinfo v) acc)
          Base.Set.empty
          vars
      in
      Zone.filter_base (fun b -> not (Base.Set.mem b bases))
    in
    { state with locs = remove_unscoped_bases state.locs; }


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
