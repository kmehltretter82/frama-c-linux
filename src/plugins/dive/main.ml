(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C plug-in `IIG'.                       *)
(*                                                                        *)
(*  Copyright (C) 2018                                                    *)
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

let add_target graph lval_text sid =
  let sid = Integer.to_int sid in
  let stmt, kf =
    try
      Kernel_function.find_from_sid sid
    with Not_found ->
      Self.abort "Cannot find the statement with sid %d." sid
  in
  let lval =
    try
      let loc = Cil_datatype.Stmt.loc stmt in
      let term = !Db.Properties.Interp.term kf ~loc lval_text in
      !Db.Properties.Interp.term_to_lval ~result:None term
    with
    | Parsing.Parse_error ->
      Self.abort "Syntax error when parsing: %s" lval_text
    | Logic_interp.Error (_, s) ->
      Self.abort "%s" s
    | Db.Properties.Interp.No_conversion ->
      Self.abort "The given term is not an lvalue: %s" lval_text
  in
  let kinstr = Cil_types.Kstmt stmt in
  Build.add_lval graph kinstr lval

let is_folded_base vi =
  Self.FoldedBases.mem vi.Cil_types.vname

let main () =
  if not (Self.Targets.is_empty ()) then begin
    (* Create the initial graph  *)
    let graph = Build.create ~is_folded_base () in
    (* Add targets to it *)
    let add_target' (lval,sids) =
      List.iter (add_target graph lval) sids
    in
    Self.Targets.iter add_target';
    (* Output it *)
    let out_channel = open_out "imprecisions.dot" in
    Imprecision_graph.ouptput_to_dot out_channel graph.Build.graph;
    close_out out_channel
  end

let () =
  Db.Main.extend main

