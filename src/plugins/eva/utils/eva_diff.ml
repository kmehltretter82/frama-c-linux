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

let import_base = function
  | Base.Var (vi, _validity) -> Base.of_varinfo (import_varinfo vi)
  | CLogic_Var (lvi, _, _) -> Base.of_c_logic_var (import_logic_var lvi)
  | Allocated (vi, _, _) -> Base.of_varinfo (import_varinfo vi)
  | Null -> Base.null
  | String (id, cstring) ->
    let create _ =
      let loc = Cil_datatype.Location.unknown in
      let cst =
        match cstring with
        | Base.CSString s -> Cil_types.Const (CStr s)
        | Base.CSWstring s -> Const (CWStr s)
      in
      (* TODO: try to retrieve the correct expression in the new AST. *)
      let exp = Cil.new_exp ~loc cst in
      Base.of_string_exp exp
    in
    Datatype.Int.Hashtbl.memo literal_strings id create

let import_bases =
  let cache_name = "Eva_diff.import_bases" in
  let f base = Base.Hptset.singleton (import_base base) in
  let joiner = Base.Hptset.union in
  let empty = Base.Hptset.empty in
  Base.Hptset.cached_fold ~cache_name ~temporary:false ~f ~joiner ~empty

let import_cvalue_map =
  let cache_name = "Eva_diff.import_cvalue" in
  let f base ival = Cvalue.V.inject (import_base base) ival in
  let projection _ = assert false in
  let joiner = Cvalue.V.join in
  let empty = Cvalue.V.bottom in
  Cvalue.V.cached_fold ~cache_name ~temporary:false ~projection ~f ~joiner ~empty

let import_cvalue =
  let open Cvalue.V in
  function
  | Top (Top, _) as top -> top
  | Top (Set bases, origin) ->
    let bases = import_bases bases in
    inject_top_origin origin bases
  | map -> import_cvalue_map map

let import_cvalue_or_initialized =
  Cvalue.V_Or_Uninitialized.map import_cvalue

let import_offsetmap_aux offsm =
  Cvalue.V_Offsetmap.fold
    (fun itv (v, size, offset) acc ->
       let v = import_cvalue_or_initialized v in
       Cvalue.V_Offsetmap.add ~exact:true itv (v, size, offset) acc)
    offsm Cvalue.V_Offsetmap.empty

module Cacheable_Offsm = struct
  type t = Cvalue.V_Offsetmap.t
  let hash = Cvalue.V_Offsetmap.hash
  let sentinel : t = Cvalue.V_Offsetmap.empty
  let equal : t -> t -> bool = (==)
end
module Cache_Offsm = Binary_cache.Arity_One (Cacheable_Offsm) (Cacheable_Offsm)

let import_offsetmap = Cache_Offsm.merge import_offsetmap_aux

let clear_caches () =
  Cache_Offsm.clear ();
  Datatype.Int.Hashtbl.clear literal_strings

let import_zone =
  let cache_name = "Eva_diff.import_zone" in
  let f base itv =
    let itv =
      try Int_Intervals.(inject (project_set itv))
      with Abstract_interp.Error_Top -> Int_Intervals.top
    in
    Locations.Zone.inject (import_base base) itv
  in
  let projection _base = Int_Intervals.top in
  let joiner = Locations.Zone.join in
  let empty = Locations.Zone.bottom in
  let import =
    Locations.Zone.cached_fold
      ~cache_name ~temporary:false ~f ~projection ~joiner ~empty
  in
  fun zone ->
    try import zone
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
    over_allocs = import_zone t.over_allocs;
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


let import_callsite_kf kf = match Ast_diff.Kernel_function.find kf with
  | `Same kf | `Partial (kf, _) -> kf
  | `Not_present -> raise Not_found

let import_widening_kf kf = match Ast_diff.Kernel_function.find kf with
  | `Same kf | `Partial (kf, _) -> kf
  | `Not_present -> raise Not_found

let import_callsite_stmt stmt = match Ast_diff.Stmt.find stmt with
  | `Same stmt -> stmt
  | `Partial (stmt, diff)->
    begin
      match diff with
      | `Body_changed -> raise Not_found
      | _ -> stmt
    end
  | `Not_present -> raise Not_found

let import_widening_stmt stmt = match Ast_diff.Stmt.find stmt with
  | `Same stmt | `Partial (stmt, _) -> stmt
  | `Not_present -> raise Not_found

let import_inout_kf kf = match Ast_diff.Kernel_function.find kf with
  | `Same kf -> kf
  | `Partial (_, _) | `Not_present -> raise Not_found
