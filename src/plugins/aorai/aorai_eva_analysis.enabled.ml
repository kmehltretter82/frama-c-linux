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

let show_aorai_variable state fmt var_name =
  let vi = Data_for_aorai.(get_varinfo var_name) in
  let cvalue = !Db.Value.eval_expr state (Cil.evar vi) in
  try
    let i = Ival.project_int (Cvalue.V.project_ival cvalue) in
    let state_name = Data_for_aorai.getStateName (Integer.to_int i) in
    Format.fprintf fmt "%s" state_name
  with Cvalue.V.Not_based_on_null | Ival.Not_Singleton_Int |
       Z.Overflow | Not_found ->
    Format.fprintf fmt "?"

let show_val fmt (expr, v, _) =
  Format.fprintf fmt "%a in %a"
    Printer.pp_exp expr
    (Cvalue.V.pretty_typ (Some (Cil.typeOf expr))) v

let show_aorai_state = "Frama_C_show_aorai_state"

(*
let builtin_show_aorai_state state args =
  if not (Aorai_option.Deterministic.get()) then begin
    Aorai_option.warning
      ~current:true "%s can only display info for deterministic automata"
      show_aorai_state
  end else begin
    let history = Data_for_aorai.(curState :: (whole_history ())) in
    Aorai_option.result ~current:true "@[<hv>%a@]"
      (Pretty_utils.pp_list ~sep:" <- " (show_aorai_variable state)) history;
    if args <> [] then begin
      Aorai_option.result ~current:true "@[<hv>%a@]"
        (Pretty_utils.pp_list ~sep:"," show_val) args
    end;
  end;
  (* Return value : returns nothing, changes nothing *)
  {
    Value_types.c_values = [None, state];
    c_clobbered = Base.SetLattice.bottom;
    c_from = None;
    c_cacheable = Value_types.Cacheable;
  }
*)

let () =
  Cil_builtins.add_custom_builtin
    (fun () -> (show_aorai_state,Cil.voidType,[],true))

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
