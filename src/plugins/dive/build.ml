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

let get_loc_filename loc =
  Filepath.(Normalized.to_pretty_string (fst loc).pos_path)

let is_foldable_type typ =
  match Cil.unrollType typ with
  | TArray _ | TComp _ -> true
  | TVoid _ | TInt _ | TEnum _ | TFloat _ | TPtr _ | TFun _
  | TBuiltin_va_list _ -> false
  | TNamed _ -> assert false (* the type have been unrolled *)

exception Complex_location

let to_simple_location lval (l : Locations.location)
  : Cil_types.varinfo * Ival.t =
  let open Locations in
  match l.loc with
  | Location_Bits.Map m ->
    let one_couple base ival acc =
      if Extlib.has_some acc then raise Complex_location;
      match base with
      | Base.Var (vi,_) -> Some (vi, ival)
      | _ -> raise Complex_location
    in
    let r = Location_Bits.M.fold one_couple m None in
    if not (Extlib.has_some r) then begin
      Self.warning "Cannot resolve location %a" Cil_printer.pp_lval lval;
      raise Complex_location
    end;
    Extlib.the r
  | _ -> raise Complex_location

let to_symbolic_location ~is_folded_base kinstr lval =
  let sl_location = !Db.Value.lval_to_loc kinstr lval in
  let typ = Cil.typeOfLval lval in
  match to_simple_location lval sl_location with
  | vi, ival ->
    let sl_function = Kernel_function.find_defining_kf vi in
    let sl_file = get_loc_filename vi.vdecl in 
    let default = {
      sl_kind=Imprecise ; sl_location;
      sl_lval=lval ; sl_function ; sl_file
    } in
    let base' = Var vi in
    if is_foldable_type vi.vtype && is_folded_base vi then
      {default with sl_kind=Folded ; sl_lval=(base',NoOffset)}
    else
      begin try
          let offset = Ival.project_int ival
          and matching = Bit_utils.MatchType typ in
          let offset', _ = Bit_utils.find_offset vi.vtype ~offset matching in
          {default with sl_kind=Precise ; sl_lval=(base',offset')}
        with Ival.Not_Singleton_Int ->
          default
      end
  | exception Complex_location ->
    match kinstr with
    | Kglobal -> assert false
    | Kstmt stmt ->
      let kf = Kernel_function.find_englobing_kf stmt in
      let loc = Kernel_function.get_location kf in
      let sl_file = get_loc_filename loc in 
      {
        sl_kind=Imprecise ; sl_location;
        sl_lval=lval ; sl_function=Some kf ; sl_file
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
  is_hidden_base: Cil_types.varinfo -> bool;
  mutable roots: Graph.vertex list;
}

let no_base _vi = false

let create ?(is_folded_base=no_base) ?(is_hidden_base=no_base) () =
  !Db.Value.compute ();
  {
    graph = Graph.create ();
    table = Table.create 13;
    is_folded_base;
    is_hidden_base;
    roots = [];
  }

let is_hidden_location context sl =
  match sl.sl_lval with
  | Var vi, _ when context.is_hidden_base vi -> true
  | _ -> false

let add_lval ?(depth_limit=1) context kinstr lval =
  let {graph; table; is_folded_base} = context in

  (* Update a vertex associated to an lvalue, creating one if needed *)
  let update_vertex kinstr lval =
    (* If possible, refine the lval to a non-symbolic one *)
    let symbolic_location = to_symbolic_location ~is_folded_base kinstr lval in
    if is_hidden_location context symbolic_location then
      None
    else begin
      (* Add a vertex if necessary *)
      let v = Table.memo table symbolic_location (Graph.create_vertex graph) in
      (* Update the precision information *)
      if is_imprecise_data kinstr lval then
        v.Graph.vertex_imprecise_data <- true;
      Some v
    end
  in

  let rec build_vertex_deps v =
    let lval = v.Graph.vertex_location.sl_lval in
    if v.Graph.vertex_location.sl_kind != Imprecise then
      build_writes_deps v lval;
    match lval with
    | Var vi, NoOffset when vi.vformal -> build_arg_deps v vi
    | _ -> ()

  and build_writes_deps src lval =
    let zone = !Db.Value.lval_to_zone kinstr lval in
    let writes = Studia.Writes.compute zone
    and add_deps (stmt,effects) =
      match stmt.skind with
      | Instr instr when effects.Studia.Writes.direct ->
        build_instr_deps src stmt instr
      | _ -> ()
    in
    List.iter add_deps writes;

  and build_arg_deps src vi =
    assert vi.vformal;
    let kf = Extlib.the (Kernel_function.find_defining_kf vi) in
    let pos = Kernel_function.get_formal_position vi kf in
    let callsites = Kernel_function.find_syntactic_callsites kf
    and add_deps (_caller_kf, stmt) =
      match stmt.skind with
      | Instr (Call (_,_,args,_))
      | Instr (Local_init (_, ConsInit (_, args, _), _)) ->
        let exp = List.nth args pos in
        build_exp_deps src stmt Data exp
      | _ ->
        assert false (* Callsites can only be Call or ConsInit *)
    in
    List.iter add_deps callsites

  and build_return_deps src stmt args kf =
    match Kernel_function.find_return kf with
    | {skind = Return (Some {enode = Lval lval_res},_)} ->
      build_lval_deps src stmt Data lval_res
    | _ -> assert false (* Cil invariant *)
    | exception Kernel_function.No_Statement -> (* the function is only a prototype *)
      (* TODO: read assigns instead *)
      List.iter (build_exp_deps src stmt Data) args

  and build_call_deps src stmt callee args =
    (* build_exp_deps src stmt Callee callee; *)
    let kinstr = Kstmt stmt in
    let _,set = !Db.Value.expr_to_kernel_function kinstr ~deps:None callee in
    Kernel_function.Hptset.iter (build_return_deps src stmt args) set

  and build_instr_deps src stmt = function
    | Set (_, exp, _) ->
      build_exp_deps src stmt Data exp
    | Call (_, callee, args, _) -> build_call_deps src stmt callee args
    | Local_init (dest, ConsInit (f, args, k), loc) ->
      let as_func _dest callee args _loc =
        build_call_deps src stmt callee args
      in
      Cil.treat_constructor_as_func as_func dest f args k loc
    | Local_init (_, AssignInit init, _)  ->
      build_init_deps src stmt init
    | Asm _ -> () (* TODO : tell the user it's not supported *)
    | Skip _ | Code_annot _ -> ()

  and build_init_deps src stmt = function
    | SingleInit exp ->
      build_exp_deps src stmt Data exp
    | CompoundInit (_typ, initl) ->
      List.iter (fun (_offset, init) -> build_init_deps src stmt init) initl

  and build_exp_deps src stmt kind exp =
    match exp.enode with
    | Const _
    | SizeOf _ | SizeOfE _ | SizeOfStr _
    | AlignOf _  | AlignOfE _
    | AddrOf _ | StartOf _ -> ()
    | Lval lval ->
      build_lval_deps src stmt kind lval
    | UnOp (_,e,_) | CastE (_,e) | Info (e,_) ->
      build_exp_deps src stmt kind e
    | BinOp (_,e1,e2,_) ->
      build_exp_deps src stmt kind e1;
      build_exp_deps  src stmt kind e2

  and build_lval_deps src stmt kind lval =
    (* Do not add dependency to constants or functions *)
    if Cil.is_modifiable_lval lval || true then
      match update_vertex (Kstmt stmt) lval with
      | Some dst -> Graph.create_edge ~allow_folding:true graph dst kind src
      | None -> ()
  in


  let queue : (Graph.vertex_label * int) Queue.t = Queue.create () in

  (* Create the root *)
  begin match update_vertex kinstr lval with
    | Some root ->
      context.roots <- root :: context.roots;
      Queue.add (root,0) queue;
    | None -> ()
  end;

  (* Breadth first search *)
  while not (Queue.is_empty queue) do
    let v,depth = Queue.take queue in
    if not (v.Graph.vertex_deps_computed) && depth < depth_limit then begin
      build_vertex_deps v;
      v.Graph.vertex_deps_computed <- true;
      Graph.iter_pred (fun w -> Queue.add (w,depth+1) queue) graph v
    end;
  done;

