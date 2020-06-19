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

type format = Dot | Json

let output format context basename =
  let filename, output_function = match format with
    | Dot -> basename ^ ".dot", Imprecision_graph.ouptput_to_dot
    | Json -> basename ^ ".json", Imprecision_graph.ouptput_to_json
  in
  Self.result "output to %s" filename;
  let out_channel = open_out filename in
  output_function out_channel (Build.get_graph context);
  close_out out_channel

let main () =
  if not (Self.FromBases.is_empty () &&
          Self.FromFunctionAlarms.is_empty ()) then begin
    (* Create the initial graph  *)
    let context = Build.create () in
    (* Handle parameters *)
    Self.UnfoldedBases.iter (Build.unfold_base context);
    Self.HiddenBases.iter (Build.hide_base context);
    let depth = Self.DepthLimit.get () in
    (* Add targeted vars to it *)
    Self.FromBases.iter (Build.add_var ~depth context);
    (* Add alarms *)
    let add_alarm _emitter kf stmt ~rank:_ alarm _code_annot =
      if Self.FromFunctionAlarms.mem kf then
        Build.add_alarm ~depth context stmt alarm
    in
    if not (Self.FromFunctionAlarms.is_empty ()) then
      Alarms.iter add_alarm;
    (* Output it *)
    if Self.OutputDot.get () <> "" then
      output Dot context (Self.OutputDot.get ());
    if Self.OutputJson.get () <> "" then
      output Json context (Self.OutputJson.get ());
  end

let () =
  Db.Main.extend main
