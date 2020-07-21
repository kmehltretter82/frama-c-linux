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

open Server
open Cil_types

let package =
  Package.package
    ~plugin:"eva"
    ~name:"general"
    ~title:"Eva General Services"
    ~readme:"eva.md"
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

(**************************************************************************)
