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

let () = Request.register ~package
    ~kind:`GET ~name:"isComputed"
    ~descr:(Markdown.plain "True if the Eva analysis has been done")
    ~input:(module Data.Junit) ~output:(module Data.Jbool)
    Db.Value.is_computed

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

  let tag value name label descr =
    Enum.tag ~name
      ~label:(Markdown.plain label)
      ~descr:(Markdown.plain descr) ~value dictionary

  let tag_not_computed =
    tag (Error NotComputed) "not_computed" ""
      "The Eva taint analysis has not been computed"

  let tag_error =
    tag (Error LogicError) "error" "Error"
      "Error: the memory zone on which this property depends could not be computed"

  let tag_not_applicable =
    tag (Error Irrelevant) "not_applicable" "—"
      "No taint for this kind of property"

  let tag_tainted =
    tag (Ok true) "tainted" "yes"
      "Tainted property: this property is related to a memory zone that \
       can be affected by an attacker, according to the Eva taint domain."

  let tag_not_tainted =
    tag (Ok false) "not_tainted" "no"
      "Untainted property: this property is safe, \
       according to the Eva taint domain."

  let () = Enum.set_lookup dictionary
      begin function
        | Error Taint_domain.NotComputed -> tag_not_computed
        | Error Taint_domain.Irrelevant -> tag_not_applicable
        | Error Taint_domain.LogicError -> tag_error
        | Ok true -> tag_tainted
        | Ok false -> tag_not_tainted
      end

  let data = Request.dictionary ~package ~name:"taintStatus"
      ~descr:(Markdown.plain "TODO") dictionary

  include (val data : S with type t = (bool, taint_error) result)
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

(**************************************************************************)
