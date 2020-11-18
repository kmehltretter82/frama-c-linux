(**************************************************************************)
(*                                                                        *)
(*  This file is part of Aorai plug-in of Frama-C.                        *)
(*                                                                        *)
(*  Copyright (C) 2007-2020                                               *)
(*    CEA (Commissariat à l'énergie atomique et aux énergies              *)
(*         alternatives)                                                  *)
(*    INRIA (Institut National de Recherche en Informatique et en         *)
(*           Automatique)                                                 *)
(*    INSA  (Institut National des Sciences Appliquees)                   *)
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

let add_slevel_annotation vi kind =
  match kind with
  | Aorai_visitors.Aux_funcs.(Pre _ | Post _) ->
    let kf = Globals.Functions.get vi in
    let stmt = Kernel_function.find_first_stmt kf
    and loc = Kernel_function.get_location kf
    and emitter = Aorai_option.emitter in
    Eva.Eva_annotations.(add_slevel_annot ~emitter ~loc stmt SlevelFull)
  | _ -> ()

let add_slevel_annotations () =
  Aorai_visitors.Aux_funcs.iter add_slevel_annotation

let add_partitioning varname =
  match Data_for_aorai.get_varinfo_option varname with
  | None -> ()
  | Some vi -> Eva.Value_parameters.use_global_value_partitioning vi

let add_state_variables_partitioning () =
  add_partitioning Data_for_aorai.curState;
  List.iter add_partitioning (Data_for_aorai.whole_history ())

let setup () =
  add_slevel_annotations ();
  add_state_variables_partitioning ()
