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

open Cil_types
open Dependency_types


(* --- Locations handling --- *)

let singleton_location l =
  let open Locations in
  match l.loc with
  | Location_Bits.Map m when Location_Bits.cardinal_zero_or_one l.loc ->
    let to_lval base ival acc =
      if Extlib.has_some acc then raise Exit;
      Some (base, Ival.project_int ival)
    in
    begin
      try Location_Bits.M.fold to_lval m None
      with Exit | Ival.Not_Singleton_Int ->  None
    end
  | _ -> None

let location_to_lval ~typ location =
  match singleton_location location with
  | Some (Base.Var (vi,_), offset) ->
    let base' = Var vi in
    let offset', _typ =
      Bit_utils.find_offset vi.vtype ~offset (Bit_utils.MatchType typ)
    in
    Some (base', offset')
  | _ -> None

let is_precise_location location =
  Locations.valid_cardinal_zero_or_one ~for_writing:false location


(* --- Precision evaluation --- *)

let _fval_contains_maximal_bounds fkind fval =
  let top = Fval.top_finite (Fval.kind fkind) in
  Fval.has_greater_min_bound top fval >= 0 ||
  Fval.has_smaller_max_bound top fval >= 0


let precision_limits =
  let single = float_of_string "0x1p+120"
  and double = float_of_string "0x1p+960"
  and long_double = float_of_string "0x1p+15360"
  in function 
  | FFloat      -> single
  | FDouble     -> double
  | FLongDouble -> long_double

let fval_has_large_range fkind fval =
  let limit = precision_limits fkind in
  match Fval.min_and_max fval with
  | None, _ -> false
  | Some (min,max), _ ->
    let min' = Fval.F.to_float min and max' = Fval.F.to_float max in
    if (min' < 0.0) = (max' < 0.0) then
      max' -. min' >= limit
    else
      min' <= -.limit || max' >= limit

let is_imprecise_data kinstr lval =
  let typ = Cil.typeOfLval lval in
  let state = Db.Value.get_state kinstr in
  let _,cvalue = !Db.Value.eval_lval None state lval in
  match Cvalue.V.project_ival cvalue, typ with
  | Ival.Float fval, TFloat (fkind,_) ->
    fval_has_large_range fkind fval
  | _ -> false
  | exception Cvalue.V.Not_based_on_null -> false


(* --- Graph building --- *)

module Graph = Imprecision_graph
module Table = FCHashtbl.Make (Locations.Location)

type t = {
  graph: Graph.t;
  table: Graph.vertex Table.t;
}

let create () =
  !Db.Value.compute ();
  {
    graph = Graph.create ();
    table = Table.create 13;
  }


let add_lval {graph; table} kinstr lval =
  (* TODO: derecursify if necessary *)
  let rec build_vertex kinstr lval =
    let location = !Db.Value.lval_to_loc kinstr lval in
    let precise_location = is_precise_location location in
    let typ = Cil.typeOfLval lval in
    (* If possible, refine the lval to a non-symbolic one *)
    let lval = Extlib.opt_conv lval (location_to_lval ~typ location) in
    let v = try
      Table.find table location
    with Not_found ->
      let properties = {
        node_lval = lval;
        node_imprecise_data = false;
        node_imprecise_location = not precise_location;
      } in
      let v = Graph.create_vertex graph properties in
      Table.add table location v;
      begin match lval with
        | Var vi, NoOffset when vi.vformal ->
          let kf = Extlib.the (Kernel_function.find_defining_kf vi) in
          let pos = Kernel_function.get_formal_position vi kf in
          let callsites = Kernel_function.find_syntactic_callsites kf
          and add_argument_dependencies (_caller_kf, stmt) =
            match stmt.skind with
            | Instr (Call (_,_,args,_))
            | Instr (Local_init (_, ConsInit (_, args, _), _)) ->
              let exp = List.nth args pos in
              build_exp_deps v (Kstmt stmt) Data exp
            | _ ->
              assert false (* Callsites can only be Call or ConsInit *)
          in
          List.iter add_argument_dependencies callsites
        | _ -> ()
      end;

      if precise_location then begin
        let zone = !Db.Value.lval_to_zone kinstr lval in
        let writes = Studia.Writes.compute zone
        and add_write_dependencies (stmt,effects) =
          match stmt.skind with
          | Instr instr when effects.Studia.Writes.direct ->
            build_instr_deps v (Kstmt stmt) instr
          | _ -> ()
        in
        List.iter add_write_dependencies writes;
      end;
      v
  in
  if is_imprecise_data kinstr lval then
    v.Graph.vertex_properties.node_imprecise_data <- true;
  v

  and build_instr_deps src kinstr = function
    | Set (_, exp, _) ->
      build_exp_deps src kinstr Data exp
    | Call (_, _callee, args, _) ->
      (* build_exp_deps src kinstr Callee callee; *)
      List.iter (build_exp_deps src kinstr Data) args
    | Local_init (_, ConsInit (_, args, _), _) ->
      List.iter (build_exp_deps src kinstr Data) args
    | Local_init (_, AssignInit init, _)  ->
      build_init_deps src kinstr init
    | Asm _ -> () (* TODO : tell the user it's not supported *)
    | Skip _ | Code_annot _ -> ()

  and build_init_deps src kinstr = function
    | SingleInit exp ->
      build_exp_deps src kinstr Data exp
    | CompoundInit (_typ, initl) ->
      List.iter (fun (_offset, init) -> build_init_deps src kinstr init) initl

  and build_exp_deps src kinstr kind exp =
    match exp.enode with
    | Const _
    | SizeOf _ | SizeOfE _ | SizeOfStr _
    | AlignOf _ -> () | AlignOfE _
    | AddrOf _ | StartOf _     -> ()
    | Lval lval ->
      build_lval_deps src kinstr kind lval
    | UnOp (_,e,_) | CastE (_,e) | Info (e,_) ->
      build_exp_deps src kinstr kind e
    | BinOp (_,e1,e2,_) ->
      build_exp_deps src kinstr kind e1;
      build_exp_deps  src kinstr kind e2

  and build_lval_deps src kinstr kind lval =
    let dst = build_vertex kinstr lval in
    Graph.create_edge graph src kind dst
  in
  ignore (build_vertex kinstr lval)

