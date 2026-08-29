(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C) 2026 Frama-C Linux contributors                         *)
(*                                                                        *)
(**************************************************************************)

open Cil_types

module VarMap = Cil_datatype.Varinfo.Map
module VarSet = Cil_datatype.Varinfo.Set

(** This check recognizes a narrow ARM64 MTE helper-domain protocol:
    after [folio_test_hugetlb(folio)] succeeds, a page related to [folio]
    must not be passed to a base-page MTE state helper.  In particular, this
    catches boolean fall-through such as

      (folio_test_hugetlb(folio) && folio_mte_tagged(folio)) ||
        page_mte_tagged(page)

    where the right operand remains reachable for an untagged hugetlb folio.
    It is a path-sensitive code-shape check, not a general points-to analysis. *)

type predicate_map = varinfo VarMap.t
type relation_graph = VarSet.t VarMap.t

type state =
  | Unreachable
  | Reachable of VarSet.t

let variable_of_expression expression =
  match (Cil.stripCasts expression).enode with
  | Lval (Var variable, NoOffset) -> Some variable
  | _ -> None

let add_relation_one_way left right graph =
  let related =
    Option.value ~default:VarSet.empty (VarMap.find_opt left graph)
  in
  VarMap.add left (VarSet.add right related) graph

let add_relation left right graph =
  graph
  |> add_relation_one_way left right
  |> add_relation_one_way right left

let is_folio_conversion = function
  | "page_folio" | "compound_head" | "_compound_head" -> true
  | _ -> false

let is_base_page_mte_helper = function
  | "page_mte_tagged" | "set_page_mte_tagged"
  | "try_page_mte_tagging" -> true
  | _ -> false

class shape_collector = object (self)
  inherit Visitor.frama_c_inplace

  val mutable predicates = VarMap.empty
  val mutable relations = VarMap.empty

  method predicates = predicates
  method relations = relations

  method private add_predicate result argument =
    match variable_of_expression argument with
    | Some folio -> predicates <- VarMap.add result folio predicates
    | None -> ()

  method private add_relation result argument =
    match variable_of_expression argument with
    | Some source -> relations <- add_relation result source relations
    | None -> ()

  method private collect_call result function_info arguments =
    match function_info.vname, arguments with
    | "folio_test_hugetlb", [argument] ->
      self#add_predicate result argument
    | name, [argument] when is_folio_conversion name ->
      self#add_relation result argument
    | _ -> ()

  method! vinst instruction =
    begin
      match instruction with
      | Set ((Var result, NoOffset), expression, _) ->
        self#add_relation result expression
      | Call (Some (Var result, NoOffset), Var function_info, arguments, _) ->
        self#collect_call result function_info arguments
      | Local_init (result, AssignInit (SingleInit expression), _) ->
        self#add_relation result expression
      | Local_init (result, ConsInit (function_info, arguments, _), _) ->
        self#collect_call result function_info arguments
      | Set _ | Call _ | Local_init (_, AssignInit (CompoundInit _), _)
      | Asm _ | Skip _ | Code_annot _ -> ()
    end;
    Cil.DoChildren
end

let collect_shapes function_definition =
  let collector = new shape_collector in
  ignore
    (Visitor.visitFramacFunction
       (collector :> Visitor.frama_c_visitor) function_definition);
  collector#predicates, collector#relations

let rec predicate_of_condition predicates polarity expression =
  let expression = Cil.stripCasts expression in
  match expression.enode with
  | Lval (Var result, NoOffset) ->
    Option.map
      (fun folio -> folio, polarity)
      (VarMap.find_opt result predicates)
  | UnOp (LNot, nested, _) ->
    predicate_of_condition predicates (not polarity) nested
  | _ -> None

let transfer_guard predicates _statement condition state =
  match state, predicate_of_condition predicates true condition with
  | Unreachable, _ -> Unreachable, Unreachable
  | Reachable _, None -> state, state
  | Reachable hugetlb, Some (folio, true_means_hugetlb) ->
    let with_hugetlb = Reachable (VarSet.add folio hugetlb)
    and without_hugetlb = Reachable (VarSet.remove folio hugetlb) in
    if true_means_hugetlb then with_hugetlb, without_hugetlb
    else without_hugetlb, with_hugetlb

let related relations left right =
  let rec visit seen = function
    | [] -> false
    | variable :: remaining when VarSet.mem variable seen ->
      visit seen remaining
    | variable :: _ when Cil_datatype.Varinfo.equal variable right -> true
    | variable :: remaining ->
      let seen = VarSet.add variable seen in
      let adjacent =
        Option.value ~default:VarSet.empty (VarMap.find_opt variable relations)
        |> VarSet.elements
      in
      visit seen (adjacent @ remaining)
  in
  visit VarSet.empty [left]

let base_page_helper_call = function
  | { skind =
        Instr (Call (_, Var function_info, argument :: _, _)); _ }
    when is_base_page_mte_helper function_info.vname ->
    Option.map (fun page -> function_info.vname, page)
      (variable_of_expression argument)
  | _ -> None

let mismatched_folio relations hugetlb page =
  List.find_opt
    (fun folio -> related relations folio page)
    (VarSet.elements hugetlb)

let analyze_function kernel_function =
  let function_definition = Kernel_function.get_definition kernel_function in
  let predicates, relations = collect_shapes function_definition in
  match function_definition.sbody.bstmts with
  | [] -> 0
  | _ when VarMap.is_empty predicates -> 0
  | first_statement :: _ ->
    let module Function_environment =
      (val Dataflows.function_env kernel_function : Dataflows.FUNCTION_ENV)
    in
    let module Transfer = struct
      type t = state

      let bottom = Unreachable
      let init = [first_statement, Reachable VarSet.empty]

      let join left right =
        match left, right with
        | Unreachable, state | state, Unreachable -> state
        | Reachable left, Reachable right ->
          Reachable (VarSet.union left right)

      let is_included left right =
        match left, right with
        | Unreachable, _ -> true
        | Reachable _, Unreachable -> false
        | Reachable left, Reachable right -> VarSet.subset left right

      let join_and_is_included new_state old_state =
        join new_state old_state, is_included new_state old_state

      let pretty formatter = function
        | Unreachable -> Format.pp_print_string formatter "unreachable"
        | Reachable hugetlb ->
          Pretty_utils.pp_iter
            ~pre:"hugetlb={" ~suf:"}" ~sep:", "
            VarSet.iter
            (fun formatter variable ->
               Format.pp_print_string formatter variable.vname)
            formatter hugetlb

      let transfer_stmt statement state =
        match statement.skind with
        | If _ ->
          Dataflows.transfer_if_from_guard
            (transfer_guard predicates) statement state
        | _ -> List.map (fun successor -> successor, state) statement.succs
    end
    in
    let module Analysis =
      Dataflows.Simple_forward (Function_environment) (Transfer)
    in
    let violations = ref 0 in
    Analysis.iter_on_result
      (fun statement state ->
         match state, base_page_helper_call statement with
         | Reachable hugetlb, Some (helper, page) ->
           begin
             match mismatched_folio relations hugetlb page with
             | None -> ()
             | Some folio ->
               incr violations;
               Options.warning
                 ~wkey:Options.wkey_mte_helper_domain
                 ~source:(Cil_datatype.Stmt.loc statement)
                 "ARM64 MTE helper-domain mismatch: %s may receive page '%s' \
                  while its related folio '%s' is known to be hugetlb"
                 helper page.vname folio.vname
           end
         | Unreachable, _ | Reachable _, None -> ());
    !violations

let run () =
  Ast.compute ();
  Globals.Functions.fold
    (fun kernel_function violations ->
       if Kernel_function.is_definition kernel_function then
         violations + analyze_function kernel_function
       else violations)
    0
