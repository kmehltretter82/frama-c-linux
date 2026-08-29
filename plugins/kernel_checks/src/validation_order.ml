(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C) 2026 Frama-C Linux contributors                         *)
(*                                                                        *)
(**************************************************************************)

open Cil_types

module VarSet = Cil_datatype.Varinfo.Set
module IntSet = Set.Make (Int)

type mutation_summaries = (int, IntSet.t) Hashtbl.t

(** A pointer formal is treated as mutable state when the typed translation
    unit proves a write through it, directly or through a defined direct-call
    chain.  Opaque and indirect calls are not guessed to mutate their
    arguments.  The remaining pointer formals are possible request/input
    objects. *)

let pointer_formals function_definition =
  List.fold_left
    (fun pointers formal ->
       if Ast_types.C.is_ptr formal.vtype then VarSet.add formal pointers
       else pointers)
    VarSet.empty function_definition.sformals

let parameters_in_expression parameters expression =
  VarSet.inter parameters (Cil.extract_varinfos_from_exp expression)

let parameters_written_through parameters = function
  | Mem address, _ -> parameters_in_expression parameters address
  | Var _, _ -> VarSet.empty

let has_prefix prefix string =
  let prefix_length = String.length prefix in
  String.length string >= prefix_length
  && String.sub string 0 prefix_length = prefix

(** Tracepoints observe their arguments.  KVM's VM-bug helpers intentionally
    mark a VM dead after an internal invariant failure; that fail-stop state is
    not a transactional mutation caused by rejected userspace input. *)
let is_out_of_scope_effect function_info =
  has_prefix "trace_" function_info.vname
  || function_info.vname = "kvm_vm_bugged"
  || function_info.vname = "kvm_vm_dead"

let formal_may_mutate summaries function_info index =
  if is_out_of_scope_effect function_info then false
  else
    match Hashtbl.find_opt summaries function_info.vid with
    | Some summary -> IntSet.mem index summary
    | None -> false

let parameters_passed_to_mutable_formals
    summaries parameters function_info arguments =
  let _, formals, _, _ = Cil.splitFunctionTypeVI function_info in
  let rec collect index mutated arguments formals =
    match arguments, formals with
    | argument :: arguments, _ :: formals ->
      let mutated =
        if formal_may_mutate summaries function_info index then
          VarSet.union
            mutated (parameters_in_expression parameters argument)
        else mutated
      in
      collect (index + 1) mutated arguments formals
    | _, _ -> mutated
  in
  match formals with
  | None -> VarSet.empty
  | Some formals -> collect 0 VarSet.empty arguments formals

let parameters_mutated_by_instruction summaries parameters = function
  | Set (destination, _, _) -> parameters_written_through parameters destination
  | Call (destination, Var function_info, arguments, _) ->
    let destination_mutations =
      Option.fold
        ~none:VarSet.empty
        ~some:(parameters_written_through parameters)
        destination
    in
    VarSet.union destination_mutations
      (parameters_passed_to_mutable_formals
         summaries parameters function_info arguments)
  | Call (destination, Mem _, _, _) ->
    Option.fold
      ~none:VarSet.empty
      ~some:(parameters_written_through parameters)
      destination
  | Local_init (_, ConsInit (function_info, arguments, _), _) ->
    parameters_passed_to_mutable_formals
      summaries parameters function_info arguments
  | Local_init (_, AssignInit _, _)
  | Asm _ | Skip _ | Code_annot _ -> VarSet.empty

class mutation_collector summaries parameters = object
  inherit Visitor.frama_c_inplace

  val mutable mutated = VarSet.empty
  method mutated = mutated

  method! vinst instruction =
    mutated <-
      VarSet.union mutated
        (parameters_mutated_by_instruction summaries parameters instruction);
    Cil.DoChildren
end

let collect_mutable_pointer_parameters summaries function_definition =
  let parameters = pointer_formals function_definition in
  let collector = new mutation_collector summaries parameters in
  ignore
    (Visitor.visitFramacFunction
       (collector :> Visitor.frama_c_visitor) function_definition);
  parameters, collector#mutated

let indices_of_parameters formals parameters =
  let rec collect index indices = function
    | [] -> indices
    | formal :: formals ->
      let indices =
        if VarSet.mem formal parameters then IntSet.add index indices
        else indices
      in
      collect (index + 1) indices formals
  in
  collect 0 IntSet.empty formals

let parameters_at_indices formals indices =
  let rec collect index parameters = function
    | [] -> parameters
    | formal :: formals ->
      let parameters =
        if IntSet.mem index indices then VarSet.add formal parameters
        else parameters
      in
      collect (index + 1) parameters formals
  in
  collect 0 VarSet.empty formals

let compute_mutation_summaries () =
  let definitions =
    Globals.Functions.fold
      (fun kernel_function definitions ->
         if Kernel_function.is_definition kernel_function then
           kernel_function :: definitions
         else definitions)
      []
  in
  let summaries = Hashtbl.create (List.length definitions) in
  List.iter
    (fun kernel_function ->
       let function_definition =
         Kernel_function.get_definition kernel_function
       in
       Hashtbl.replace summaries function_definition.svar.vid IntSet.empty)
    definitions;
  let changed = ref true in
  while !changed do
    changed := false;
    List.iter
      (fun kernel_function ->
         let function_definition =
           Kernel_function.get_definition kernel_function
         in
         let _, mutated =
           collect_mutable_pointer_parameters summaries function_definition
         in
         let discovered =
           indices_of_parameters function_definition.sformals mutated
         in
         let previous =
           Option.value
             ~default:IntSet.empty
             (Hashtbl.find_opt summaries function_definition.svar.vid)
         in
         let summary = IntSet.union previous discovered in
         if not (IntSet.equal previous summary) then begin
           Hashtbl.replace summaries function_definition.svar.vid summary;
           changed := true
         end)
      definitions
  done;
  summaries

let mutable_pointer_parameters summaries function_definition =
  let parameters = pointer_formals function_definition in
  let indices =
    Option.value
      ~default:IntSet.empty
      (Hashtbl.find_opt summaries function_definition.svar.vid)
  in
  parameters,
  VarSet.inter parameters
    (parameters_at_indices function_definition.sformals indices)

type reachable_state = {
  tainted : VarSet.t;
  mutated : VarSet.t;
}

type state =
  | Unreachable
  | Reachable of reachable_state

let expression_is_tainted tainted expression =
  not
    (VarSet.is_empty
       (VarSet.inter tainted (Cil.extract_varinfos_from_exp expression)))

let rec initializer_is_tainted tainted = function
  | SingleInit expression -> expression_is_tainted tainted expression
  | CompoundInit (_, initializers) ->
    List.exists
      (fun (_, init) -> initializer_is_tainted tainted init)
      initializers

let update_local_taint variable is_tainted tainted =
  if is_tainted then VarSet.add variable tainted
  else VarSet.remove variable tainted

let update_destination_taint destination is_tainted tainted =
  match destination with
  | Var variable, _ -> update_local_taint variable is_tainted tainted
  | Mem _, _ -> tainted

let arguments_are_tainted tainted arguments =
  List.exists (expression_is_tainted tainted) arguments

let transfer_instruction summaries pointer_parameters reachable instruction =
  let mutated =
    VarSet.union reachable.mutated
      (parameters_mutated_by_instruction
         summaries pointer_parameters instruction)
  in
  let tainted =
    match instruction with
    | Set (destination, expression, _) ->
      update_destination_taint destination
        (expression_is_tainted reachable.tainted expression)
        reachable.tainted
    | Call (destination, _, arguments, _) ->
      Option.fold
        ~none:reachable.tainted
        ~some:(fun destination ->
          update_destination_taint destination
            (arguments_are_tainted reachable.tainted arguments)
            reachable.tainted)
        destination
    | Local_init (variable, AssignInit init, _) ->
      update_local_taint variable
        (initializer_is_tainted reachable.tainted init)
        reachable.tainted
    | Local_init (variable, ConsInit (_, arguments, _), _) ->
      update_local_taint variable
        (arguments_are_tainted reachable.tainted arguments)
        reachable.tainted
    | Asm _ | Skip _ | Code_annot _ -> reachable.tainted
  in
  { tainted; mutated }

let transfer_instruction summaries pointer_parameters state instruction =
  match state with
  | Unreachable -> Unreachable
  | Reachable reachable ->
    Reachable
      (transfer_instruction summaries pointer_parameters reachable instruction)

let is_einval expression =
  match Cil.constFoldToInt expression with
  | Some value -> Z.equal value (Z.of_int (-22))
  | None -> false

let returns_variable variable statement =
  match statement.skind with
  | Return (Some { enode = Lval (Var returned, NoOffset); _ }, _) ->
    Cil_datatype.Varinfo.equal variable returned
  | _ -> false

let rec direct_einval_return block =
  match block.bstmts with
  | [{ skind = Return (Some expression, _); _ } as statement]
    when is_einval expression -> Some statement
  | [ ({ skind =
           Instr (Set ((Var result, NoOffset), expression, _)); _ }
       as assignment);
      { skind = Goto (target, _); _ } ]
    when is_einval expression && returns_variable result !target ->
    Some assignment
  | [{ skind = Block nested; _ }] -> direct_einval_return nested
  | _ -> None

let validation_return statement state =
  match statement.skind, state with
  | If (condition, then_block, else_block, _), Reachable reachable
    when not (VarSet.is_empty reachable.mutated)
         && expression_is_tainted reachable.tainted condition ->
    begin
      match direct_einval_return then_block with
      | Some return -> Some (return, reachable.mutated)
      | None ->
        Option.map
          (fun return -> return, reachable.mutated)
          (direct_einval_return else_block)
    end
  | _, Unreachable | _, Reachable _ -> None

let join_reachable left right =
  {
    tainted = VarSet.union left.tainted right.tainted;
    mutated = VarSet.union left.mutated right.mutated;
  }

let state_is_included left right =
  match left, right with
  | Unreachable, _ -> true
  | Reachable _, Unreachable -> false
  | Reachable left, Reachable right ->
    VarSet.subset left.tainted right.tainted
    && VarSet.subset left.mutated right.mutated

let join_state left right =
  match left, right with
  | Unreachable, state | state, Unreachable -> state
  | Reachable left, Reachable right -> Reachable (join_reachable left right)

let pretty_var_set formatter variables =
  Pretty_utils.pp_iter
    ~pre:"" ~suf:"" ~sep:", "
    VarSet.iter
    (fun formatter variable -> Format.pp_print_string formatter variable.vname)
    formatter variables

let analyze_function summaries kernel_function =
  let function_definition = Kernel_function.get_definition kernel_function in
  let pointer_parameters, mutable_parameters =
    mutable_pointer_parameters summaries function_definition
  in
  let input_parameters = VarSet.diff pointer_parameters mutable_parameters in
  match function_definition.sbody.bstmts with
  | [] -> 0
  | _ when VarSet.is_empty mutable_parameters
           || VarSet.is_empty input_parameters -> 0
  | first_statement :: _ ->
    let module Function_environment =
      (val Dataflows.function_env kernel_function : Dataflows.FUNCTION_ENV)
    in
    let module Transfer = struct
      type t = state

      let bottom = Unreachable
      let init =
        [ first_statement,
          Reachable { tainted = input_parameters; mutated = VarSet.empty } ]

      let join = join_state
      let is_included = state_is_included

      let join_and_is_included new_state old_state =
        let joined = join_state new_state old_state in
        joined, state_is_included new_state old_state

      let pretty formatter = function
        | Unreachable -> Format.pp_print_string formatter "unreachable"
        | Reachable reachable ->
          Format.fprintf formatter "tainted={%a}; mutated={%a}"
            pretty_var_set reachable.tainted
            pretty_var_set reachable.mutated

      let transfer_stmt statement state =
        let state =
          match statement.skind with
          | Instr instruction ->
            transfer_instruction
              summaries pointer_parameters state instruction
          | _ -> state
        in
        List.map (fun successor -> successor, state) statement.succs
    end
    in
    let module Analysis =
      Dataflows.Simple_forward (Function_environment) (Transfer)
    in
    let candidates = ref [] in
    Analysis.iter_on_result
      (fun statement state ->
         match validation_return statement state with
         | None -> ()
         | Some (return, mutated) ->
           candidates := (return, mutated) :: !candidates);
    begin
      match
        List.sort
          (fun (left, _) (right, _) -> Int.compare left.sid right.sid)
          !candidates
      with
      | [] -> 0
      | (return, mutated) :: _ ->
        Options.warning
          ~wkey:Options.wkey_validation_order
          ~source:(Cil_datatype.Stmt.loc return)
          "rejected-input atomicity risk in %s: input-derived validation may \
           return -EINVAL after state parameter(s) %a may have been modified"
          (Kernel_function.get_name kernel_function)
          pretty_var_set mutated;
        1
    end

let run () =
  Ast.compute ();
  let summaries = compute_mutation_summaries () in
  Globals.Functions.fold
    (fun kernel_function violations ->
       if Kernel_function.is_definition kernel_function then
         violations + analyze_function summaries kernel_function
       else violations)
    0
