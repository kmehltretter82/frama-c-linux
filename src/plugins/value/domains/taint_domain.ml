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
open Locations

type taint = {
  zone: Zone.t;
  control_stmt: stmt option;
}

module LatticeTaint = struct

  (* Frama-C "datatype" for type [taint]. *)
  include Datatype.Make_with_collections(struct
      include Datatype.Serializable_undefined

      type t = taint

      let name = "Value.Taint.t"

      let reprs =
        [ { zone = List.hd Zone.reprs;
            control_stmt = None; } ]

      let structural_descr =
        Structural_descr.t_abstract (* TODO *)

      let compare t1 t2 =
        let c = Zone.compare t1.zone t2.zone in
        if c <> 0
        then c
        else
          Option.compare
            Cil_datatype.Stmt.compare
            t1.control_stmt t2.control_stmt

      let equal = Datatype.from_compare

      let pretty fmt t =
        Format.fprintf fmt "@[<hov>%a@]" Zone.pretty t.zone

      let hash t =
        Hashtbl.hash
          (Zone.hash t.zone,
           Hashtbl.hash t.control_stmt)

      let copy c = c

    end)

  (* Initial state at the start of the computation: nothing is tainted yet. *)
  let empty = {
    zone = Zone.bottom;
    control_stmt = None;
  }

  (* Top state: everything is tainted. *)
  let top = {
    zone = Zone.top;
    control_stmt = None;
  }

  (* Join: keep pointwise over-approximation. *)
  let join t1 t2 =
    let join_control_stmt cs1 cs2 =
      match cs1, cs2 with
      | None, None ->
        None
      | (Some _ as cs), None
      | None, (Some _ as cs) ->
        cs
      | Some s1, Some s2 ->
        if Cil_datatype.Stmt.equal s1 s2
        then cs1
        else
          Value_parameters.fatal
            "@[<hv>@[Different control statements:@]@ %a@ vs.@ %a.@]"
            (Pretty_utils.pp_opt ~none:"<None>" Cil_printer.pp_stmt) cs1
            (Pretty_utils.pp_opt ~none:"<None>" Cil_printer.pp_stmt) cs2
    in
    { zone = Zone.join t1.zone t2.zone;
      control_stmt = join_control_stmt t1.control_stmt t2.control_stmt; }

  (* Add zone to state. *)
  let add t e =
    { t with zone = Zone.join t.zone e; }

  (* Remove zone from state. *)
  let remove t e =
    { t with zone = Zone.diff t.zone e; }

  (* The memory locations are finite, so the ascending chain property is
     already verified. We simply use a join. *)
  let widen _ _ t1 t2 = join t1 t2

  let narrow t1 t2 =
    `Value {
      zone = Zone.narrow t1.zone t2.zone;
      control_stmt = None;      (* TODO *)
    }

  (* Inclusion testing: pointwise. *)
  let is_included t1 t2 =
    Zone.is_included t1.zone t2.zone

  (* Intersection testing: pointwise. *)
  let intersects t e =
    Zone.intersects t.zone e

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

  let is_under_taint_condition state stmt =
    let kf = Kernel_function.find_englobing_kf stmt in
    Option.fold
      ~none:false
      ~some:(fun cs ->
          let always_reachable =
            List.fold_left
              (fun acc s -> Stmts_graph.stmt_can_reach kf s stmt && acc)
              true
              cs.succs
          in
          not always_reachable)
      state.control_stmt

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
        if is_under_taint_condition state stmt
        then LatticeTaint.add state lv_zone
        else
          let state = { state with control_stmt = None; } in
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
    let to_loc = loc_of_lval valuation in
    let exp_zone = Value_util.zone_of_expr to_loc exp in
    let state =
      if LatticeTaint.intersects state exp_zone &&
         (state.control_stmt = None || not (is_under_taint_condition state stmt))
      then { state with control_stmt = Some stmt; }
      else state
    in
    `Value state

  let start_call stmt call valuation state =
    let state = LatticeTaint.add state (zone_of_taint_annot stmt) in
    let state =
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

  let finalize_call _stmt call ~pre ~post =
    let state = { post with control_stmt = pre.control_stmt } in
    let state =
      match call.Eval.return with
      | None ->
        state
      | Some vi ->
        let result_zone = Locations.zone_of_varinfo vi in
        if LatticeTaint.intersects post result_zone
        then state
        else LatticeTaint.remove state result_zone
    in
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
    { state with zone = remove_unscoped_bases state.zone; }


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
