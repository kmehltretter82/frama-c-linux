(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C) 2026 Frama-C Linux contributors                         *)
(*                                                                        *)
(**************************************************************************)

open Cil_types

module IntMap = Map.Make (Int)
module IntSet = Set.Make (Int)
module VarSet = Cil_datatype.Varinfo.Set

(** A deliberately narrow check for ignored KVM guest-memory transfer
    failures.  It reports only when a direct call to a known fallible helper
    discards its result and a reachable return then advertises either the exact
    simple guest-address value or, for a signed non-boolean integer protocol,
    zero.  This avoids classifying void best-effort updates and common
    non-status zero returns. *)

type ignored_call = {
  statement_id : int;
  helper : string;
  zero_is_success : bool;
  successful_variables : VarSet.t;
  source : Fileloc.t;
}

type state =
  | Unreachable
  | Reachable of ignored_call IntMap.t

let is_guest_memory_helper = function
  | "kvm_read_guest" | "kvm_read_guest_lock" | "kvm_read_guest_page"
  | "kvm_vcpu_read_guest" | "kvm_vcpu_read_guest_atomic"
  | "kvm_vcpu_read_guest_page"
  | "kvm_write_guest" | "kvm_write_guest_lock" | "kvm_write_guest_page"
  | "kvm_vcpu_write_guest" | "kvm_vcpu_write_guest_page" -> true
  | _ -> false

let variable_of_expression expression =
  match (Cil.stripCasts expression).enode with
  | Lval (Var variable, NoOffset) -> Some variable
  | _ -> None

let ignored_call_of_statement ~zero_is_success statement =
  match statement.skind with
  | Instr (Call (None, Var function_info, arguments, source))
    when is_guest_memory_helper function_info.vname ->
    begin
      match List.nth_opt arguments 1 with
      | None -> None
      | Some address ->
        let successful_variables =
          Option.fold
            ~none:VarSet.empty ~some:VarSet.singleton
            (variable_of_expression address)
        in
        Some {
          statement_id = statement.sid;
          helper = function_info.vname;
          zero_is_success;
          successful_variables;
          source;
        }
    end
  | _ -> None

let add_ignored_call ~zero_is_success statement = function
  | Unreachable -> Unreachable
  | Reachable pending ->
    begin
      match ignored_call_of_statement ~zero_is_success statement with
      | None -> Reachable pending
      | Some call ->
        Reachable (IntMap.add call.statement_id call pending)
    end

let join_pending left right =
  IntMap.union
    (fun _ left right ->
       Some {
         left with
         successful_variables =
           VarSet.union
             left.successful_variables right.successful_variables;
       })
    left right

let pending_is_included left right =
  IntMap.for_all
    (fun statement_id call ->
       match IntMap.find_opt statement_id right with
       | None -> false
       | Some other ->
         VarSet.subset call.successful_variables other.successful_variables)
    left

let join_state left right =
  match left, right with
  | Unreachable, state | state, Unreachable -> state
  | Reachable left, Reachable right -> Reachable (join_pending left right)

let state_is_included left right =
  match left, right with
  | Unreachable, _ -> true
  | Reachable _, Unreachable -> false
  | Reachable left, Reachable right -> pending_is_included left right

let expression_is_zero expression =
  match Cil.constFoldToInt expression with
  | Some value -> Z.equal value Z.zero
  | None -> false

let expression_is_successful call expression =
  (call.zero_is_success && expression_is_zero expression)
  || Option.fold
       ~none:false
       ~some:(fun variable -> VarSet.mem variable call.successful_variables)
       (variable_of_expression expression)

let update_successful_variable variable expression call =
  let successful_variables =
    if expression_is_successful call expression then
      VarSet.add variable call.successful_variables
    else VarSet.remove variable call.successful_variables
  in
  { call with successful_variables }

let clear_successful_variable variable call =
  {
    call with
    successful_variables = VarSet.remove variable call.successful_variables;
  }

let update_pending statement pending =
  match statement.skind with
  | Instr (Set ((Var variable, NoOffset), expression, _)) ->
    IntMap.map (update_successful_variable variable expression) pending
  | Instr (Call (Some (Var variable, NoOffset), _, _, _)) ->
    IntMap.map (clear_successful_variable variable) pending
  | Instr (Local_init (variable, AssignInit (SingleInit expression), _)) ->
    IntMap.map (update_successful_variable variable expression) pending
  | Instr (Local_init (variable, ConsInit _, _)) ->
    IntMap.map (clear_successful_variable variable) pending
  | _ -> pending

let transfer_statement ~zero_is_success statement = function
  | Unreachable -> Unreachable
  | Reachable pending ->
    add_ignored_call ~zero_is_success statement
      (Reachable (update_pending statement pending))

let successful_return call = function
  | { skind = Return (Some expression, _); _ }
    when expression_is_successful call expression ->
    Some expression
  | _ -> None

let function_return_type function_definition =
  let return_type, _, _, _ = Cil.splitFunctionTypeVI function_definition.svar in
  return_type

let analyze_function kernel_function =
  let function_definition = Kernel_function.get_definition kernel_function in
  let return_type = function_return_type function_definition in
  let zero_is_success =
    Cil.isSignedInteger return_type && not (Ast_types.C.is_bool return_type)
  in
  match function_definition.sbody.bstmts with
  | [] -> 0
  | _ when Ast_types.C.is_void return_type -> 0
  | first_statement :: _ ->
    let module Function_environment =
      (val Dataflows.function_env kernel_function : Dataflows.FUNCTION_ENV)
    in
    let module Transfer = struct
      type t = state

      let bottom = Unreachable
      let init = [first_statement, Reachable IntMap.empty]
      let join = join_state
      let is_included = state_is_included

      let join_and_is_included new_state old_state =
        join_state new_state old_state,
        state_is_included new_state old_state

      let pretty formatter = function
        | Unreachable -> Format.pp_print_string formatter "unreachable"
        | Reachable pending ->
          let statement_ids =
            List.map fst (IntMap.bindings pending)
          in
          Format.fprintf formatter "ignored-guest-memory-results=%a"
            (Pretty_utils.pp_list
               ~pre:"{" ~suf:"}" ~sep:", " Format.pp_print_int)
            statement_ids

      let transfer_stmt statement state =
        let state = transfer_statement ~zero_is_success statement state in
        List.map (fun successor -> successor, state) statement.succs
    end
    in
    let module Analysis =
      Dataflows.Simple_forward (Function_environment) (Transfer)
    in
    let reported = ref IntSet.empty in
    Analysis.iter_on_result
      (fun statement state ->
         match state with
         | Unreachable -> ()
         | Reachable pending ->
           IntMap.iter
             (fun statement_id call ->
                match successful_return call statement with
                | None -> ()
                | Some _ when IntSet.mem statement_id !reported -> ()
                | Some expression ->
                  reported := IntSet.add statement_id !reported;
                  Options.warning
                    ~wkey:Options.wkey_guest_memory_result
                    ~source:call.source
                    "ignored %s() failure in %s may be hidden by successful \
                     return %a"
                    call.helper
                    (Kernel_function.get_name kernel_function)
                    Printer.pp_exp expression)
             pending);
    IntSet.cardinal !reported

let run () =
  Ast.compute ();
  Globals.Functions.fold
    (fun kernel_function violations ->
       if Kernel_function.is_definition kernel_function then
         violations + analyze_function kernel_function
       else violations)
    0
