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

include Compute

let print_dot basename kf =
  let filename = basename ^ "." ^ Kernel_function.get_name kf ^ ".dot" in
  Print.build_dot filename kf;
  Postdominators_parameters.result "dot file generated in %s" filename

let output () =
  let dot_postdom = Postdominators_parameters.DotPostdomBasename.get () in
  if dot_postdom <> "" then (
    Ast.compute ();
    Globals.Functions.iter (fun kf ->
        if Kernel_function.is_definition kf then
          print_dot dot_postdom kf)
  )

let output, _ = State_builder.apply_once "Postdominators.Compute.output"
    [Compute.self] output

let () = Boot.Main.extend output
