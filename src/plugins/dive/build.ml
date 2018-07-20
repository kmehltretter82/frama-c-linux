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


(* --- Locations handling --- *)

exception Not_simple_location

let is_foldable_type typ =
  match Cil.unrollType typ with
  | TArray _ | TComp _ -> true
  | TVoid _ | TInt _ | TEnum _ | TFloat _ | TPtr _ | TFun _
  | TBuiltin_va_list _ -> false
  | TNamed _ -> assert false (* the type have been unrolled *)

let to_simple_location (l : Locations.location) : Base.t * Ival.t =
  let open Locations in
  match l.loc with
  | Location_Bits.Map m ->
    let one_couple base ival acc =
      if Extlib.has_some acc then raise Not_simple_location;
      Some (base, ival)
    in
    Extlib.the (Location_Bits.M.fold one_couple m None)
  | _ -> raise Not_simple_location

let to_symbolic_location ~is_folded_base kinstr lval =
  let location = !Db.Value.lval_to_loc kinstr lval in
  let typ = Cil.typeOfLval lval in
  try match to_simple_location location with
    | Base.Var (vi,_), ival ->
      let sl_owner = Kernel_function.find_defining_kf vi in
      let base' = Var vi in
      let sl_kind, sl_lval, sl_location =
        try
          let kind, offset' =
            if is_foldable_type vi.vtype && is_folded_base vi then
              Folded, NoOffset
            else
              let offset = Ival.project_int ival
              and matching = Bit_utils.MatchType typ in
              let offset', _ = Bit_utils.find_offset vi.vtype ~offset matching in
              Precise, offset'
          in
          let lval' = (base',offset') in
          let location' = !Db.Value.lval_to_loc kinstr lval' in
          kind, lval', location'
        with Ival.Not_Singleton_Int ->
          Imprecise, lval, location
      in
      { sl_lval; sl_location; sl_owner; sl_kind}
  | _ -> raise Not_simple_location
  with
  | Not_simple_location ->
    {
      sl_lval = lval;
      sl_location = location;
      sl_owner = None;
      sl_kind = Imprecise;
    }


(* --- Graph building --- *)

module Graph = Imprecision_graph
module Table = FCHashtbl.Make
    (struct
      module L = Locations.Location
      type t = symbolic_location
      let equal a b = L.equal a.sl_location b.sl_location
      let hash a = L.hash a.sl_location
    end)

type t = {
  graph: Graph.t;
  table: Graph.vertex Table.t;
  is_folded_base: Cil_types.varinfo -> bool;
}

let no_folded_base _vi = false

let create ?(is_folded_base=no_folded_base) () =
  !Db.Value.compute ();
  {
    graph = Graph.create ();
    table = Table.create 13;
    is_folded_base
  }


let add_lval {graph; table; is_folded_base} kinstr lval =
  (* TODO: derecursify if necessary *)
  let rec update_vertex kinstr lval =
    (* If possible, refine the lval to a non-symbolic one *)
    let symbolic_location = to_symbolic_location ~is_folded_base kinstr lval in
    (* Not exactly as Table.memo as Table.add is done before recursive calls *)
    let v = try
        Table.find table symbolic_location
      with Not_found ->
        create_vertex symbolic_location
    in
    if is_imprecise_data kinstr lval then
      v.Graph.vertex_imprecise_data <- true;
    v

  and create_vertex symbolic_location =
    let v = Graph.create_vertex graph symbolic_location in
    Table.add table symbolic_location v;
    let lval = symbolic_location.sl_lval in
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

    if symbolic_location.sl_kind != Imprecise then begin
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
    let dst = update_vertex kinstr lval in
    Graph.create_edge graph src kind dst
  in
  ignore (update_vertex kinstr lval)

