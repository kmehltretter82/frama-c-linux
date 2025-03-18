(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2025                                               *)
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

let package = Package.package ~plugin:"impact" ~name:"impact" ~title:"Impact" ()

(* Convert the result of the impact analysis into a list of localizables. *)
let impact_to_localizable_list impact =
  let add_kf_nodes kf nodes acc =
    let stmts = Compute_impact.nodes_to_stmts nodes in
    let add_stmt kf acc stmt = Printer_tag.PStmtStart (kf, stmt) :: acc in
    List.fold_left (add_stmt kf) acc stmts
  in
  Kernel_function.Map.fold add_kf_nodes impact []

let impact_statement stmt =
  let kf = Kernel_function.find_englobing_kf stmt in
  let skip = Compute_impact.skip () in
  let reason = Options.Reason.get () in
  let restrict = Locations.Zone.top in
  let impact, _initial, _reason =
    Compute_impact.nodes_impacted_by_stmts ~skip ~restrict ~reason kf [stmt]
  in
  impact_to_localizable_list impact

let () =
  Request.register ~package
    ~kind:`GET ~name:"impactStatement"
    ~descr:(Markdown.plain "Compute the impact of a statement")
    ~input:(module Kernel_ast.Stmt)
    ~output:(module Data.Jlist (Kernel_ast.Marker))
    impact_statement
