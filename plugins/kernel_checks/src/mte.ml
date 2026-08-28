(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C) 2026 Frama-C Linux contributors                         *)
(*                                                                        *)
(**************************************************************************)

open Cil_types

(** Whether some path has acquired one-shot MTE initialization state without
    publishing the corresponding tagged state. This is deliberately a
    code-shape protocol, not a model of the kernel's page or folio aliases. *)
type state =
  | Unreachable
  | Reachable of bool

let direct_call_name = function
  | Call (_, Var function_info, _, _) -> Some function_info.vname
  | Call (_, Mem _, _, _) -> None
  | Set _ | Local_init _ | Asm _ | Skip _ | Code_annot _ -> None

let is_acquire = function
  | "try_page_mte_tagging" | "folio_try_hugetlb_mte_tagging" -> true
  | _ -> false

let is_publish = function
  | "set_page_mte_tagged" | "folio_set_hugetlb_mte_tagged" -> true
  | _ -> false

let is_faultable_access = function
  | "mte_copy_tags_from_user"
  | "mte_copy_tags_to_user"
  | "copy_from_user"
  | "copy_to_user"
  | "clear_user" -> true
  | _ -> false

let ignored_result = function
  | Call (None, _, _, _) -> true
  | Call (Some _, _, _, _)
  | Set _ | Local_init _ | Asm _ | Skip _ | Code_annot _ -> false

let transfer_instruction state instruction =
  match state with
  | Unreachable -> Unreachable
  | Reachable held ->
    begin
      match direct_call_name instruction with
      | Some name when is_acquire name && ignored_result instruction ->
        Reachable true
      | Some name when is_publish name -> Reachable false
      | Some _ | None -> Reachable held
    end

let may_hold = function
  | Reachable true -> true
  | Unreachable | Reachable false -> false

let faultable_call = function
  | { skind = Instr instruction; _ } ->
    begin
      match direct_call_name instruction with
      | Some name when is_faultable_access name -> Some name
      | Some _ | None -> None
    end
  | _ -> None

let analyze_function kernel_function =
  let function_definition = Kernel_function.get_definition kernel_function in
  match function_definition.sbody.bstmts with
  | [] -> 0
  | first_statement :: _ ->
    let module Function_environment =
      (val Dataflows.function_env kernel_function : Dataflows.FUNCTION_ENV)
    in
    let module Transfer = struct
      type t = state

      let bottom = Unreachable
      let init = [first_statement, Reachable false]

      let join left right =
        match left, right with
        | Unreachable, state | state, Unreachable -> state
        | Reachable left, Reachable right -> Reachable (left || right)

      let is_included left right = join left right = right

      let join_and_is_included new_state old_state =
        let joined = join new_state old_state in
        joined, joined = old_state

      let pretty formatter = function
        | Unreachable -> Format.pp_print_string formatter "unreachable"
        | Reachable false -> Format.pp_print_string formatter "unlocked"
        | Reachable true -> Format.pp_print_string formatter "initializing"

      let transfer_stmt statement state =
        let state =
          match statement.skind with
          | Instr instruction -> transfer_instruction state instruction
          | _ -> state
        in
        List.map (fun successor -> successor, state) statement.succs
    end
    in
    let module Analysis =
      Dataflows.Simple_forward (Function_environment) (Transfer)
    in
    let violations = ref 0 in
    Analysis.iter_on_result
      (fun statement state ->
         match may_hold state, faultable_call statement with
         | true, Some name ->
           incr violations;
           Options.warning
             ~wkey:Options.wkey_mte_init
             ~source:(Cil_datatype.Stmt.loc statement)
             "MTE initialization protocol violation: faultable call %s may \
              execute after an ignored tag-initialization acquisition and \
              before tagged state is published"
             name
         | false, _ | true, None -> ());
    !violations

let run () =
  Ast.compute ();
  Globals.Functions.fold
    (fun kernel_function violations ->
       if Kernel_function.is_definition kernel_function then
         violations + analyze_function kernel_function
       else
         violations)
    0
