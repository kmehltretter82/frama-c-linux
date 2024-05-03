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

open Cil_types

let join_logic_deps logic_deps =
  Cil_datatype.Logic_label.Map.fold
    (fun _ -> Locations.Zone.join) logic_deps Locations.Zone.bottom

let predicate_deps ~pre ~here predicate =
  let env = Eval_terms.env_annot ~pre ~here () in
  let logic_deps = Eval_terms.predicate_deps env predicate in
  Option.map join_logic_deps logic_deps

let term_deps state t =
  try
    let env = Eval_terms.env_only_here state in
    let r = Eval_terms.eval_term ~alarm_mode:Eval_terms.Ignore env t in
    let zone = join_logic_deps r.Eval_terms.ldeps in
    Some zone
  with Eval_terms.LogicEvalError _ -> None

let compute_term_deps stmt t =
  let state = Results.(before stmt |> get_cvalue_model) in
  term_deps state t

let () = Logic_deps.compute_term_deps := compute_term_deps

let valid_behaviors kf state =
  Populate_spec.populate_funspec kf [`Assigns];
  let funspec = Annotations.funspec kf in
  let eval_predicate pred =
    match Eval_terms.(eval_predicate (env_pre_f ~pre:state ()) pred) with
    | True -> Alarmset.True
    | False -> Alarmset.False
    | Unknown -> Alarmset.Unknown
  in
  let ab = Active_behaviors.create eval_predicate funspec in
  Active_behaviors.active_behaviors ab

(* -------------------------------------------------------------------------- *)
(* --- Compute inout from assigns clauses                                 --- *)
(* -------------------------------------------------------------------------- *)

let eval_error_reason fmt e =
  if e <> Eval_terms.CAlarm
  then Eval_terms.pretty_logic_evaluation_error fmt e

let eval_tlval_as_zone assigns kind env acc t =
  try
    let alarm_mode = Eval_terms.Ignore in
    let zone = Eval_terms.eval_tlval_as_zone ~alarm_mode kind env t.it_content in
    Locations.Zone.join acc zone
  with Eval_terms.LogicEvalError e ->
    let pp_clause fmt =
      if kind = Read
      then Printer.pp_from fmt assigns
      else Printer.pp_term fmt (fst assigns).it_content
    in
    Self.warning ~current:true ~once:true
      "Failed to interpret %sassigns clause '%t'%a"
      (if kind = Read then "inputs in " else "")
      pp_clause eval_error_reason e;
    Locations.Zone.top

let assigns_inputs_to_zone state assigns =
  let env = Eval_terms.env_assigns ~pre:state in
  let treat_asgn acc (_,ins as asgn) =
    match ins with
    | FromAny -> Locations.Zone.top
    | From l -> List.fold_left (eval_tlval_as_zone asgn Read env) acc l
  in
  match assigns with
  | WritesAny -> Locations.Zone.top
  | Writes l  -> List.fold_left treat_asgn Locations.Zone.bottom l

let assigns_outputs_to_zone ~result state assigns =
  let env = Eval_terms.env_post_f ~pre:state ~post:state ~result () in
  let treat_asgn acc (out,_ as asgn) =
    if Logic_utils.is_result out.it_content && result = None
    then acc
    else eval_tlval_as_zone asgn Write env acc out
  in
  match assigns with
  | WritesAny -> Locations.Zone.top
  | Writes l  -> List.fold_left treat_asgn Locations.Zone.bottom l

type tlval_zones = {
  under: Locations.Zone.t;
  over: Locations.Zone.t;
  deps: Locations.Zone.t;
}

let assigns_tlval_to_zones state access tlval =
  let env = Eval_terms.env_post_f ~pre:state ~post:state ~result:None () in
  let alarm_mode = Eval_terms.Ignore in
  try
    let under, over =
      Eval_terms.eval_tlval_as_zone_under_over ~alarm_mode access env tlval
    in
    let deps = join_logic_deps (Eval_terms.tlval_deps env tlval) in
    Some { under; over; deps; }
  with Eval_terms.LogicEvalError _ -> None


(* -------------------------------------------------------------------------- *)
(* --- Verify assigns clauses                                             --- *)
(* -------------------------------------------------------------------------- *)

(* Eval: under-approximation of the term.  Note that ACSL states
   that assigns clauses are evaluated in the pre-state.
   We skip [\result]: it is meaningless when evaluating the 'assigns' part,
   and a special treatment must be done in [from] clauses anyway. *)
let eval_assigns_from pre_state it =
  let term = it.it_content in
  if Logic_utils.is_result it.it_content then
    Locations.Zone.bottom
  else
    try
      let eval_env = Eval_terms.env_assigns ~pre:pre_state in
      let under, _ =
        Eval_terms.eval_tlval_as_zone_under_over
          ~alarm_mode:Eval_terms.Ignore Locations.Read eval_env term
      in
      under
    with Eval_terms.LogicEvalError _ -> Locations.Zone.bottom

(** Compute the validity status for [from] in [pre_state], assuming the
    entire clause is [assigns asgn \from from]. The inferred dependencies
    are [found_froms], while [asgn] evaluates to [assigns_zone]. *)
let check_from pre_state asgn assigns_zone from found_assigns =
  let open Locations in
  let found_deps =
    if Logic_utils.is_result asgn.it_content then
      found_assigns.Assigns.return
    else
      Assigns.Memory.find_precise found_assigns.memory assigns_zone
  in
  let (indirect_deps,direct_deps) =
    let filter x = List.mem "indirect" x.it_content.term_name in
    List.partition filter from
  in
  (* Under-approximation of the union. *)
  let link zones = List.fold_left Zone.link Zone.bottom zones in
  let eval = eval_assigns_from pre_state in
  let stated_indirect_deps = link (List.map eval indirect_deps) in
  let stated_direct_deps = link (List.map eval direct_deps) in
  let found_direct_deps = found_deps.Deps.data in
  let found_indirect_deps = found_deps.Deps.indirect in
  let res_for_unknown txt =
    Self.debug "found_direct deps %a stated_direct_deps %a \
                found_indirect_deps %a stated_indirect_deps %a"
      Zone.pretty found_direct_deps Zone.pretty stated_direct_deps
      Zone.pretty found_indirect_deps Zone.pretty stated_indirect_deps;
    "unknown (cannot validate "^txt^" dependencies)",
    Alarmset.Unknown
  in
  match (Zone.is_included found_direct_deps stated_direct_deps,
         Zone.is_included found_indirect_deps stated_indirect_deps) with
  | true,true -> "valid", Alarmset.True
  | false,true -> res_for_unknown "direct"
  | false,false -> res_for_unknown "direct and indirect"
  | true,false -> res_for_unknown "indirect"


(* Display the message as result/warning depending on [status] *)
let msg_status status ?current ?once ?source fmt =
  if status = Alarmset.True then
    if Parameters.ValShowProgress.get ()
    then Self.result ?current ?once ?source fmt
    else Self.result ?current ?once ?source ~level:2 fmt
  else
    Self.warning
      ~wkey:Self.wkey_alarm ?current ?once ?source fmt

let pp_bhv fmt b =
  if not (Cil.is_default_behavior b)
  then Format.fprintf fmt ", behavior %s" b.b_name

let pp_header kf fmt b =
  Format.fprintf fmt "function %a%a"
    Kernel_function.pretty kf pp_bhv b


let conv_status = function
  | Alarmset.False -> Property_status.False_if_reachable;
  | Alarmset.True -> Property_status.True;
  | Alarmset.Unknown -> Property_status.Dont_know


let check_fct_assigns kf ab ~pre_state found_froms =
  let open Locations in
  let open Alarmset in
  let behaviors = Annotations.behaviors kf in
  (* Under-approximation of the union. *)
  let link zones = List.fold_left Zone.link Zone.bottom zones in
  let outputs = Assigns.outputs found_froms in
  let check_for_behavior b =
    let activity = Active_behaviors.is_active ab b in
    match activity with
    | False -> ()
    | True | Unknown ->
      let pp_activity fmt activity = match activity with
        | False -> assert false
        | True -> ()
        (* If unknown, the error may be because we did not notice
           that the behavior is inactive.  *)
        | Unknown -> Format.fprintf fmt "(the behavior may be inactive)"
      in
      (match b.b_assigns with
       | WritesAny -> ()
       | Writes(assigns_deps) ->
         let bol = Property.Id_contract (Datatype.String.Set.empty,b) in
         let ip = Option.get (Property.ip_of_assigns kf Kglobal bol b.b_assigns)
         in
         let source = fst (Property.location ip) in
         (* First, check the assigns. *)
         let assigns = List.map fst assigns_deps in
         let assigns_zones = List.map (eval_assigns_from pre_state) assigns in
         let assigns_union = link assigns_zones in
         let status_txt, vstatus, status =
           if not (Zone.is_included outputs assigns_union)
           then (
             Self.debug
               "@[Cannot prove assigns clause@]@ \
                @[<2>found assigns:  %a@]@ @[<2>stated assigns: %a@]"
               Zone.pretty outputs Zone.pretty assigns_union;
             "unknown", Unknown, Property_status.Dont_know)
           else "valid", True, Property_status.True
         in
         msg_status vstatus ~once:true ~source
           "%a: assigns got status %s.%a%t"
           (pp_header kf) b
           status_txt
           pp_activity activity
           Eva_utils.pp_callstack;
         let emit_status ppt status =
           Property_status.emit
             ~distinct:true Eva_utils.emitter ~hyps:[] ppt status
         in
         emit_status ip status;
         (* Now, checks the individual froms. *)
         let check_from ((asgn,deps) as from) assigns_zone =
           match deps with
           | FromAny -> ()
           | From deps ->
             let status_txt, status =
               check_from pre_state asgn assigns_zone deps found_froms
             in
             let ip = Option.get (Property.ip_of_from kf Kglobal bol from) in
             let source = fst (asgn.it_content.term_loc) in
             msg_status status ~once:true ~source
               "%a: \\from ... part in assign clause got status %s.%a%t"
               (pp_header kf) b
               status_txt
               pp_activity activity
               Eva_utils.pp_callstack;
             emit_status ip (conv_status status)
         in
         List.iter2 check_from assigns_deps assigns_zones)
  in List.iter check_for_behavior behaviors

let verify_assigns kf ~pre froms =
  let funspec = Annotations.funspec kf in
  let env = Eval_terms.env_pre_f ~pre () in
  let eval_predicate pred =
    match Eval_terms.eval_predicate env pred with
    | Eval_terms.True -> Alarmset.True
    | Eval_terms.False -> Alarmset.False
    | Eval_terms.Unknown -> Alarmset.Unknown
  in
  let ab = Active_behaviors.create eval_predicate funspec in
  check_fct_assigns kf ab ~pre_state:pre froms

(* -------------------------------------------------------------------------- *)
(* --- Utilitary function for Inout and From plugins                      --- *)
(* -------------------------------------------------------------------------- *)

let compute_all_callers kf =
  let rec add_callers kf acc =
    List.fold_left add_kf acc (Function_calls.callers kf)
  and add_kf acc kf =
    if Kernel_function.Hptset.mem kf acc
    then acc
    else add_callers kf (Kernel_function.Hptset.add kf acc)
  in
  add_callers kf (Kernel_function.Hptset.empty)

let is_local_or_formal_of_caller callers base =
  match Kernel_function.find_defining_kf (Base.to_varinfo base) with
  | Some kf -> Kernel_function.Hptset.mem kf callers
  | None | exception Base.Not_a_C_variable -> false

let is_formal kf base =
  match kf.fundec with
  | Definition (fundec, _) -> Base.is_formal base fundec
  | Declaration (_, vi, _, _) -> Base.is_formal_of_prototype base vi

let is_local kf base =
  match kf.fundec with
  | Definition (fundec, _) -> Base.is_local base fundec
  | Declaration _ -> false

let accept_base ~formals ~locals kf =
  let all_callers = compute_all_callers kf in
  fun base ->
    Base.is_global base
    || (formals && is_formal kf base)
    || (locals && is_local kf base)
    || is_local_or_formal_of_caller all_callers base
