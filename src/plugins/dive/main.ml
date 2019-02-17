(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C plug-in `Dive'.                      *)
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
  if not (Self.FromBases.is_empty ()) then begin
    (* Create the initial graph  *)
    let context = Build.create () in
    (* Handle parameters *)
    Self.UnfoldedBases.iter (Build.unfold_base context);
    Self.HiddenBases.iter (Build.hide_base context);
    (* Add targeted vars to it *)
    let depth_limit = Self.DepthLimit.get () in
    Self.FromBases.iter (Build.add_var ~depth_limit context);
    (* Output it *)
    let out_channel = open_out "imprecisions.dot" in
    Imprecision_graph.ouptput_to_dot out_channel (Build.get_graph context);
    close_out out_channel
  end

let () =
  Db.Main.extend main

