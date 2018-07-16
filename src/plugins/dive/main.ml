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

let main () =
  if Self.Run.get () then begin
    if Self.Lval.is_default () then
      Self.abort "You must provide a lval wtih the option %s"
        Self.Lval.option_name;
    if Self.StatementId.is_default () then
      Self.abort "You must provide a stmt with the option %s"
        Self.StatementId.option_name;
    let lval_text = Self.Lval.get () in
    let sid = Self.StatementId.get () in
    (* Statement *)
    let stmt, kf =
      try
        Kernel_function.find_from_sid sid
      with Not_found ->
        Self.abort "Cannot find the statement with sid %d." sid
    in
    (* Lval *)
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
    (* Compute *)
    let kinstr = Cil_types.Kstmt stmt in
    let graph = Build.compute kinstr lval in
    (* Output *)
    let out_channel = open_out "imprecisions.dot" in
    Imprecision_graph.ouptput_to_dot out_channel graph;
    close_out out_channel
  end

let () =
  Db.Main.extend main

