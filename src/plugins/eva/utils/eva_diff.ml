(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2023                                               *)
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

let import find elt =
  match find elt with
  | `Same elt -> elt
  | `Not_present -> raise Not_found

let import_varinfo = import Ast_diff.Varinfo.find
let import_logic_var = import Ast_diff.Logic_var.find

let literal_strings = Datatype.Int.Hashtbl.create 17
let last_literal_strings = ref 0

let import_base = function
  | Base.Var (vi, _validity) -> Base.of_varinfo (import_varinfo vi)
  | CLogic_Var (lvi, _, _) -> Base.of_c_logic_var (import_logic_var lvi)
  | Allocated (vi, _, _) -> Base.of_varinfo (import_varinfo vi)
  | Null -> Base.null
  | String (id, cstring) ->
    Datatype.Int.Hashtbl.memo literal_strings id
      (fun _ ->
         decr last_literal_strings;
         Base.of_string_id !last_literal_strings cstring)

let import_bases bases =
  Base.Hptset.(fold (fun b acc -> add (import_base b) acc) bases empty)

let import_cvalue =
  let open Cvalue.V in
  function
  | Top (Top, _) as top -> top
  | Top (Set bases, origin) ->
    let bases = import_bases bases in
    inject_top_origin origin bases
  | Map map ->
    M.fold (fun b ival acc -> add (import_base b) ival acc) map bottom

let import_cvalue_or_initialized =
  Cvalue.V_Or_Uninitialized.map import_cvalue

let import_offsetmap offsm =
  Cvalue.V_Offsetmap.fold
    (fun itv (v, size, offset) acc ->
       let v = import_cvalue_or_initialized v in
       Cvalue.V_Offsetmap.add ~exact:true itv (v, size, offset) acc)
    offsm Cvalue.V_Offsetmap.empty

let import_zone zone =
  let import base itv acc =
    let itv =
      try Int_Intervals.(inject (project_set itv))
      with Abstract_interp.Error_Top -> Int_Intervals.top
    in
    let zone = Locations.Zone.inject (import_base base) itv in
    Locations.Zone.join acc zone
  in
  try Locations.Zone.(fold_i import zone bottom)
  with Abstract_interp.Error_Top ->
    assert Locations.Zone.(equal zone top);
    Locations.Zone.top

let import_deps deps =
  Deps.{ data = import_zone deps.data;
         indirect = import_zone deps.indirect; }

let import_inout t =
  Inout_type.{
    over_inputs = import_zone t.over_inputs;
    over_inputs_if_termination = import_zone t.over_inputs_if_termination;
    over_logic_inputs = import_zone t.over_logic_inputs;
    under_outputs_if_termination = import_zone t.under_outputs_if_termination;
    over_outputs = import_zone t.over_outputs;
    over_outputs_if_termination = import_zone t.over_outputs_if_termination;
  }


let change_to find x = Cil.ChangeTo (import find x)

let import_visitor () = object
  inherit Visitor.frama_c_copy (Project.current ())

  method! vvrbl vi = ChangeTo (import_varinfo vi)
  method! vvdec vi = ChangeTo (import_varinfo vi)

  method! vcompinfo = change_to Ast_diff.Compinfo.find
  method! venuminfo = change_to Ast_diff.Enuminfo.find
  method! venumitem = change_to Ast_diff.Enumitem.find
  method! vfieldinfo = change_to Ast_diff.Fieldinfo.find

  method! vmodel_info = change_to Ast_diff.Model_info.find
  method! vlogic_info_decl = change_to Ast_diff.Logic_info.find
  method! vlogic_info_use = change_to Ast_diff.Logic_info.find
  method! vlogic_type_info_decl = change_to Ast_diff.Logic_type_info.find
  method! vlogic_type_info_use = change_to Ast_diff.Logic_type_info.find
  method! vlogic_ctor_info_decl = change_to Ast_diff.Logic_ctor_info.find
  method! vlogic_ctor_info_use = change_to Ast_diff.Logic_ctor_info.find
  method! vlogic_var_decl = change_to Ast_diff.Logic_var.find
  method! vlogic_var_use = change_to Ast_diff.Logic_var.find
end

let import_expr expr = Visitor.visitFramacExpr (import_visitor ()) expr
let import_lval lval = Visitor.visitFramacLval (import_visitor ()) lval
