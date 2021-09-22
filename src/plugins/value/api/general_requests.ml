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

open Server
open Cil_types

let package =
  Package.package
    ~plugin:"eva"
    ~name:"general"
    ~title:"Eva General Services"
    ~readme:"eva.md"
    ()

module ComputationState = struct
  open Analysis
  type t = computation_state
  let jtype =
    Data.declare ~package
      ~name:"computationStateType"
      ~descr:(Markdown.plain "State of the computation of Eva Analysis.")
      Package.(Junion [
          Jtag "not_computed" ;
          Jtag "computing" ;
          Jtag "computed"])
  let to_json = function
    | Analysis.NotComputed -> `String "not_computed"
    | Computing -> `String "computing"
    | Computed -> `String "computed"
end

let _computation_signal =
  States.register_value ~package
    ~name:"computationState"
    ~descr:(Markdown.plain "The current computation state of the analysis.")
    ~output:(module ComputationState)
    ~get:Analysis.current_computation_state
    ~add_hook:Analysis.register_computation_hook
    ()

let is_computed kf =
  Db.Value.is_computed () &&
  match kf with
  | { fundec = Definition (fundec, _) } ->
    Mark_noresults.should_memorize_function fundec
  | { fundec = Declaration _ } -> false

module CallSite = Data.Jpair (Kernel_ast.Kf) (Kernel_ast.Stmt)

let callers kf =
  let list = !Db.Value.callers kf in
  List.concat (List.map (fun (kf, l) -> List.map (fun s -> kf, s) l) list)

let () = Request.register ~package
    ~kind:`GET ~name:"getCallers"
    ~descr:(Markdown.plain "Get the list of call site of a function")
    ~input:(module Kernel_ast.Kf) ~output:(module Data.Jlist (CallSite))
    callers


(* ----- Dead code: unreachable and non-terminating statements -------------- *)

type dead_code =
  { kf: Kernel_function.t;
    unreachable : stmt list;
    non_terminating : stmt list; }

module DeadCode = struct
  open Server.Data

  type record
  let record : record Record.signature = Record.signature ()

  let unreachable = Record.field record ~name:"unreachable"
      ~descr:(Markdown.plain "List of unreachable statements.")
      (module Data.Jlist (Kernel_ast.Marker))
  let non_terminating = Record.field record ~name:"nonTerminating"
      ~descr:(Markdown.plain "List of reachable but non terminating statements.")
      (module Data.Jlist (Kernel_ast.Marker))

  let data = Record.publish record ~package ~name:"deadCode"
      ~descr:(Markdown.plain "Unreachable and non terminating statements.")

  module R : Record.S with type r = record = (val data)
  type t = dead_code
  let jtype = R.jtype

  let to_json (dead_code) =
    let make_unreachable stmt = Printer_tag.PStmt (dead_code.kf, stmt)
    and make_non_term stmt = Printer_tag.PStmtStart (dead_code.kf, stmt) in
    R.default |>
    R.set unreachable (List.map make_unreachable dead_code.unreachable) |>
    R.set non_terminating (List.map make_non_term dead_code.non_terminating) |>
    R.to_json
end

let dead_code kf =
  let empty = { kf; unreachable = []; non_terminating = [] } in
  if is_computed kf then
    let module Results = (val Analysis.current_analyzer ()) in
    let is_unreachable ~after stmt =
      Results.get_stmt_state ~after stmt = `Bottom
    in
    let classify acc stmt =
      if is_unreachable ~after:false stmt
      then { acc with unreachable = stmt :: acc.unreachable }
      else if is_unreachable ~after:true stmt
      then { acc with non_terminating = stmt :: acc.non_terminating }
      else acc
    in
    let fundec = Kernel_function.get_definition kf in
    List.fold_left classify empty fundec.sallstmts
  else empty

let () = Request.register ~package
    ~kind:`GET ~name:"getDeadCode"
    ~descr:(Markdown.plain "Get the lists of unreachable and of non terminating \
                            statements in a function")
    ~input:(module Kernel_ast.Kf)
    ~output:(module DeadCode)
    dead_code


(* ----- Red and tainted alarms --------------------------------------------- *)


module Taint = struct
  open Server.Data
  open Taint_domain

  let dictionary = Enum.dictionary ()

  let tag value name label short_descr long_descr =
    Enum.tag ~name
      ~label:(Markdown.plain label)
      ~descr:(Markdown.bold (short_descr ^ ": ") @ Markdown.plain long_descr)
      ~value dictionary

  let tag_not_computed =
    tag (Error NotComputed) "not_computed" ""
      "Not computed" "the Eva taint domain has not been enabled, \
                      or the Eva analysis has not been run"

  let tag_error =
    tag (Error LogicError) "error" "Error"
      "Error" "the memory zone on which this property depends \
               could not be computed"

  let tag_not_applicable =
    tag (Error Irrelevant) "not_applicable" "—"
      "Not applicable" "no taint for this kind of property"

  let tag_data_tainted =
    tag (Ok Data) "data_tainted" "Tainted (data)"
      "Data tainted"
      "this property is related to a memory location that can be affected \
       by an attacker"

  let tag_control_tainted =
    tag (Ok Control) "control_tainted" "Tainted (control)"
      "Control tainted"
      "this property is related to a memory location whose assignment depends \
       on path conditions that can be affected by an attacker"

  let tag_untainted =
    tag (Ok None) "not_tainted" "Untainted"
      "Untainted property" "this property is safe"

  let () = Enum.set_lookup dictionary
      begin function
        | Error Taint_domain.NotComputed -> tag_not_computed
        | Error Taint_domain.Irrelevant -> tag_not_applicable
        | Error Taint_domain.LogicError -> tag_error
        | Ok Data -> tag_data_tainted
        | Ok Control -> tag_control_tainted
        | Ok None -> tag_untainted
      end

  let data = Request.dictionary ~package ~name:"taintStatus"
      ~descr:(Markdown.plain "Taint status of logical properties") dictionary

  include (val data : S with type t = taint_result)
end


let model = States.model ()

let () = States.column model ~name:"priority"
    ~descr:(Markdown.plain "Is the property invalid in some context \
                            of the analysis?")
    ~data:(module Data.Jbool)
    ~get:(fun ip -> Red_statuses.is_red ip)

let () = States.column model ~name:"taint"
    ~descr:(Markdown.plain "Is the property tainted according to \
                            the Eva taint domain?")
    ~data:(module Taint)
    ~get:(fun ip -> Taint_domain.is_tainted_property ip)

let _array =
  States.register_array
    ~package
    ~name:"properties"
    ~descr:(Markdown.plain "Status of Registered Properties")
    ~key:(fun ip -> Kernel_ast.Marker.create (PIP ip))
    ~keyType:Kernel_ast.Marker.jproperty
    ~iter:Property_status.iter
    model


(* ----- Analysis statistics -------------------------------------------- *)

module AlarmCategory = struct
  open Server.Data

  module Tags =
  struct
    let dictionary = Enum.dictionary ()

    (* Give a normal representation of the category *)
    let repr =
      let e = List.hd Cil_datatype.Exp.reprs in
      let lv = List.hd Cil_datatype.Lval.reprs in
      function
      | Value_results.Division_by_zero -> Alarms.Division_by_zero e
      | Memory_access -> Memory_access (lv, For_reading)
      | Index_out_of_bound-> Index_out_of_bound (e, None)
      | Invalid_shift -> Invalid_shift (e, None)
      | Overflow -> Overflow (Signed, e, Integer.one, Lower_bound)
      | Uninitialized -> Uninitialized lv
      | Dangling -> Dangling lv
      | Nan_or_infinite -> Is_nan_or_infinite (e, FFloat)
      | Float_to_int -> Float_to_int (e, Integer.one, Lower_bound)
      | Other -> assert false

    let register alarm_category =
      let name, descr = match alarm_category with
        | Value_results.Other -> "other", "Any other alarm"
        | alarm_category ->
          let alarm = repr alarm_category in
          Alarms.(get_short_name alarm, get_description alarm)
      in
      Enum.tag dictionary
        ~name
        ~label:(Markdown.plain name)
        ~descr:(Markdown.plain descr)

    let division_by_zero = register Division_by_zero
    let memory_access = register Memory_access
    let index_out_of_bound = register Index_out_of_bound
    let invalid_shift = register Invalid_shift
    let overflow = register Overflow
    let uninitialized = register Uninitialized
    let dangling = register Dangling
    let nan_or_infinite = register Nan_or_infinite
    let float_to_int = register Float_to_int
    let other = register Other

    let () = Enum.set_lookup dictionary
        begin function
          | Value_results.Division_by_zero -> division_by_zero
          | Memory_access -> memory_access
          | Index_out_of_bound -> index_out_of_bound
          | Invalid_shift -> invalid_shift
          | Overflow -> overflow
          | Uninitialized -> uninitialized
          | Dangling -> dangling
          | Nan_or_infinite -> nan_or_infinite
          | Float_to_int -> float_to_int
          | Other -> other
        end
  end

  let name = "alarmCategory"
  let descr = Markdown.plain
      "The alarms are counted after being grouped by these categories"
  let data = Request.dictionary ~package ~name ~descr Tags.dictionary

  include (val data : S with type t = Value_results.alarm_category)
end

module CoverageEntry =
struct
  open Value_results
  let jtype = Package.(
      Jrecord [
        "reachable",Jnumber ;
        "dead",Jnumber ;
      ])
  let to_json x = `Assoc [
      "reachable", `Int x.reachable ;
      "dead", `Int x.dead ;
    ]
end

module Coverage =
struct
  open Value_results
  let jtype = Package.(
      Jrecord [
        "functions",CoverageEntry.jtype ;
        "statements",CoverageEntry.jtype ;
      ])
  let to_json x = `Assoc [
      "functions", CoverageEntry.to_json x.functions ;
      "statements", CoverageEntry.to_json x.statements ;
    ]
end

module EventCount =
struct
  open Value_results
  let jtype = Package.(
      Jrecord [
        "errors",Jnumber ;
        "warnings",Jnumber ;
      ])
  let to_json x = `Assoc [
      "errors", `Int x.errors ;
      "warnings", `Int x.warnings ;
    ]
end

module StatusesEntry =
struct
  open Value_results
  let jtype =
    Data.declare ~package
      ~name:"statusesEntry"
      ~descr:(Markdown.plain "Statuses count.œ")
      Package.(Jrecord [
          "valid",Jnumber ;
          "unknown",Jnumber ;
          "invalid",Jnumber ;
        ])
  let to_json x = `Assoc [
      "valid", `Int x.valid ;
      "unknown", `Int x.unknown ;
      "invalid", `Int x.invalid ;
    ]
end

module Statuses =
struct
  open Value_results
  let jtype = Package.(
      Jrecord [
        "alarms",StatusesEntry.jtype ;
        "assertions",StatusesEntry.jtype ;
        "preconds",StatusesEntry.jtype ;
      ])
  let to_json (x : statuses) = `Assoc [
      "alarms", StatusesEntry.to_json x.alarms ;
      "assertions", StatusesEntry.to_json x.assertions ;
      "preconds", StatusesEntry.to_json x.preconds ;
    ]
end

module Statistics = struct
  open Value_results
  type t = stats
  let jtype =
    Data.declare ~package
      ~name:"statistics"
      ~descr:(Markdown.plain "Statistics about an Eva analysis.")
      Package.(Jrecord [
          "coverage",Coverage.jtype ;
          "eva_events",EventCount.jtype ;
          "kernel_events",EventCount.jtype ;
          "statuses",Statuses.jtype ;
          "alarms",Jlist (Jrecord [
              "category", AlarmCategory.jtype ;
              "count", Jnumber ])])
  let to_json x = `Assoc [
      "coverage", Coverage.to_json x.coverage ;
      "eva_events", EventCount.to_json x.eva_events ;
      "kernel_events", EventCount.to_json x.kernel_events ;
      "statuses", Statuses.to_json x.statuses ;
      "alarms", `List (List.map (fun (a,c) -> `Assoc [
          "category", AlarmCategory.to_json a ;
          "count", `Int c ]) (AlarmsStats.bindings x.alarms))]
end

let _computed_signal =
  States.register_value ~package
    ~name:"stats"
    ~descr:(Markdown.plain "Statistics about the last Eva analysis")
    ~output:(module Statistics)
    ~get:Value_results.compute_stats
    ~add_hook:(Analysis.register_computation_hook ~on:Computed)
    ()


(**************************************************************************)
