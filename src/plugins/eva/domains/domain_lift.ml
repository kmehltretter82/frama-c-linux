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

open Eval

module type Input_Domain = sig
  include Abstract_domain.S
  val key: t Structure.Key_Domain.key
end

module type Conversion = sig
  type extended
  type internal
  val extend: internal -> extended
  val restrict: extended -> internal
end

module Make
    (Domain: Input_Domain)
    (Ctx: Conversion with type internal := Domain.context)
    (Val: Conversion with type internal := Domain.value)
    (Loc: Conversion with type internal := Domain.location)
= struct

  include (Domain : Datatype.S_with_collections with type t = Domain.t)
  include (Domain : Abstract_domain.Lattice with type state = Domain.state)

  let structure = Abstract.Domain.Leaf (Domain.key, (module Domain))

  let log_category = Domain.log_category

  type context = Ctx.extended
  type value = Val.extended
  type location = Loc.extended
  type origin = Domain.origin

  let extract_expr ~oracle context state exp =
    let oracle exp = oracle exp >>=: Val.restrict in
    Domain.extract_expr ~oracle context state exp >>=: fun (value, origin) ->
    Val.extend value, origin

  let extract_lval ~oracle context state lval typ loc =
    let oracle exp = oracle exp >>=: Val.restrict in
    let loc = Loc.restrict loc in
    Domain.extract_lval ~oracle context state lval typ loc
    >>=: fun (value, origin) ->
    Val.extend value, origin

  let backward_location state lval typ loc value =
    Domain.backward_location
      state lval typ (Loc.restrict loc) (Val.restrict value)
    >>-: fun (loc, value) ->
    Loc.extend loc, Val.extend value

  let reduce_further state expr value =
    let list = Domain.reduce_further state expr (Val.restrict value) in
    List.map (fun (e, v) -> e, Val.extend v) list

  let build_context state =
    let open Bottom.Operators in
    let+ context = Domain.build_context state in
    Ctx.extend context

  let lift_left left = { left with lloc = Loc.restrict left.lloc }
  let lift_flagged_value value =
    { value with v = value.v >>-: Val.restrict }
  let lift_assigned = function
    | Assign value -> Assign (Val.restrict value)
    | Copy (lval, value) -> Copy (lift_left lval, lift_flagged_value value)

  let lift_argument arg = { arg with avalue = lift_assigned arg.avalue }

  let lift_call call =
    let arguments = List.map lift_argument call.arguments in
    let rest =
      List.map (fun (exp, assigned) -> exp, lift_assigned assigned) call.rest
    in
    { call with arguments; rest }

  let lift_valuation valuation =
    let (>>>) v f = match v with
      | `Value v -> `Value (f v)
      | `Top -> `Top
    in
    let lift_record r = { r with value = lift_flagged_value r.value } in
    let lift_loc_record r = { r with loc = Loc.restrict r.loc } in
    let open Abstract_domain in
    let find expr = valuation.find expr >>> lift_record in
    let find_loc lval = valuation.find_loc lval >>> lift_loc_record in
    let fold f acc =
      valuation.fold (fun exp record acc -> f exp (lift_record record) acc) acc
    in
    { find; fold; find_loc; }

  let update valuation = Domain.update (lift_valuation valuation)

  let assign stmt lv expr value valuation state =
    Domain.assign stmt
      (lift_left lv) expr (lift_assigned value) (lift_valuation valuation) state

  let assume stmt expr positive valuation state =
    Domain.assume stmt expr positive (lift_valuation valuation) state

  let start_call stmt call recursion valuation state =
    Domain.start_call
      stmt (lift_call call) recursion (lift_valuation valuation) state

  let finalize_call stmt call recursion ~pre ~post =
    Domain.finalize_call stmt (lift_call call) recursion ~pre ~post

  let show_expr valuation = Domain.show_expr (lift_valuation valuation)

  let lift_logic_dep dep =
    let location = Option.map Loc.restrict dep.location in
    { dep with location }

  let lift_logic_assigns = function
    | Assigns (term, dep) -> Assigns (term, List.map lift_logic_dep dep)
    | (Allocates _ | Frees _) as x -> x

  let logic_assign assigns location state =
    let assigns = Option.map (fun (a, s) -> lift_logic_assigns a, s) assigns in
    Domain.logic_assign assigns (Loc.restrict location) state

  let evaluate_predicate = Domain.evaluate_predicate
  let reduce_by_predicate = Domain.reduce_by_predicate
  let interpret_acsl_extension = Domain.interpret_acsl_extension

  let enter_scope = Domain.enter_scope
  let leave_scope = Domain.leave_scope

  let enter_loop = Domain.enter_loop
  let incr_loop_counter = Domain.incr_loop_counter
  let leave_loop = Domain.leave_loop

  let empty = Domain.empty
  let initialize_variable lval loc ~initialized init_value state =
    let loc = Loc.restrict loc in
    Domain.initialize_variable lval loc ~initialized init_value state
  let initialize_variable_using_type = Domain.initialize_variable_using_type

  let relate = Domain.relate
  let filter = Domain.filter
  let reuse = Domain.reuse

  module Store = Domain.Store

  let post_analysis = Domain.post_analysis

end


(*
Local Variables:
compile-command: "make -C ../../../.."
End:
*)
