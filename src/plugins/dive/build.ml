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
open Graph_types

let dkey = Self.register_category "build"


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

let compute_node_precision kinstr lval =
  let typ = Cil.typeOfLval lval in
  let state = Db.Value.get_state kinstr in
  let _,cvalue = !Db.Value.eval_lval None state lval in
  let size = Integer.of_int (Cil.bitsSizeOf typ) in
  let cardinal = Cvalue.V.cardinal_estimate ~size cvalue in
  if Integer.(le cardinal one)
  then Singleton
  else
    match Cvalue.V.project_ival cvalue, typ with
    | Ival.Float fval, TFloat (fkind,_) ->
      if fval_has_large_range fkind fval then Wide else Normal
    | _ -> Normal
    | exception Cvalue.V.Not_based_on_null -> Normal


(* --- Locations handling --- *)

let get_loc_filename loc =
  Filepath.(Normalized.to_pretty_string (fst loc).pos_path)

let is_foldable_type typ =
  match Cil.unrollType typ with
  | TArray _ | TComp _ -> true
  | TVoid _ | TInt _ | TEnum _ | TFloat _ | TPtr _ | TFun _
  | TBuiltin_va_list _ -> false
  | TNamed _ -> assert false (* the type have been unrolled *)

let build_simple_location lval (l : Locations.location)
  : (Cil_types.varinfo * Ival.t) option =
  let open Locations in
  match l.loc with
  | Location_Bits.Map m ->
    let one_couple base ival acc =
      if Extlib.has_some acc then raise Exit;
      match base with
      | Base.Var (vi,_) -> Some (vi, ival)
      | _ -> raise Exit
    in
    begin try
        let r = Location_Bits.M.fold one_couple m None in
        if not (Extlib.has_some r) then
          Self.warning "Cannot resolve location %a" Cil_printer.pp_lval lval;
        r
      with Exit -> None
    end
  | _ -> None

let build_node_kind ~is_folded_base lval location =
  match build_simple_location lval location with
  | Some (vi, ival) ->
    if is_foldable_type vi.vtype && is_folded_base vi then
      Composite (vi)
    else
      begin try
          let typ = Cil.typeOfLval lval in
          let offset = Ival.project_int ival
          and matching = Bit_utils.MatchType typ in
          let offset', _ = Bit_utils.find_offset vi.vtype ~offset matching in
          Scalar (vi, typ, offset')
        with Bit_utils.NoMatchingOffset | Ival.Not_Singleton_Int ->
          (* TODO: handle Bit_utils.NoMatchingOffset (strict aliasing ?) *)
          Scattered (lval)
      end
  | None ->
    Scattered (lval)

let default_node_locality callstack =
  match callstack with
  | [] -> 
    (* The empty callstack can be used for global lvalues *)
    { loc_file="" ; loc_callstack=[] }
  | (kf,_kinstr) :: _ ->
    let loc_file = get_loc_filename (Kernel_function.get_location kf) in
    { loc_file ; loc_callstack=callstack }

let build_node_locality callstack node_kind =
  match Node_kind.get_base node_kind with
  | None -> default_node_locality callstack
  | Some vi ->
    match Kernel_function.find_defining_kf vi with
    | Some kf ->
      let callstack =
        try
          Callstack.pop_downto kf callstack
        with Failure _ ->
          Callstack.init kf (* TODO: complete callstack *)
      in
      default_node_locality callstack
    | None ->
      { loc_file = get_loc_filename vi.vdecl ; loc_callstack = [] }


(* --- Context object --- *)

module NodeRef = Datatype.Pair_with_collections
    (Locations.Location) (Callstack)
    (struct let module_name = "Build.NodeRef" end)

module Graph = Imprecision_graph
module NodeTable = FCHashtbl.Make (NodeRef)
module FileTable = Datatype.String.Hashtbl
module CallstackTable = Value_types.Callstack.Hashtbl
module BaseSet = Cil_datatype.Varinfo.Set
module FunctionMap = Kernel_function.Map

type t = {
  graph: Graph.t;
  node_table: node NodeTable.t;
  file_table: node FileTable.t;
  callstack_table: node CallstackTable.t;
  mutable unfolded_bases: BaseSet.t;
  mutable hidden_bases: BaseSet.t;
  mutable focus: bool FunctionMap.t;
  mutable roots: node list;
}

let reference_node_locality context node_locality =
  let { loc_file ; loc_callstack } = node_locality in
  let rec add_file _ =
    let node_locality = { node_locality with loc_callstack = [] } in
    Graph.create_node context.graph ~node_kind:Cluster ~node_locality
  and add_callstack = function
    | [] -> assert false
    | _ :: t as loc_callstack ->
      let node_locality = { node_locality with loc_callstack } in
      if t <> [] then
        ignore (CallstackTable.memo context.callstack_table t add_callstack);
      Graph.create_node context.graph ~node_kind:Cluster ~node_locality
  in
  match loc_callstack with
  | [] ->
    ignore (FileTable.memo context.file_table loc_file add_file)
  | cs ->
    ignore (CallstackTable.memo context.callstack_table cs add_callstack)


let is_folded context vi =
  not (BaseSet.mem vi context.unfolded_bases)

let is_hidden context node_kind =
  match Node_kind.get_base node_kind with
  | Some vi when BaseSet.mem vi context.hidden_bases -> true
  | _ -> false


(* --- Graph building --- *)

(* Update or create a node *)
let build_node context callstack location lval  =
  let is_folded_base = is_folded context in
  let node_kind = build_node_kind ~is_folded_base lval location in
  if is_hidden context node_kind then
    None
  else begin
    let node_locality = build_node_locality callstack node_kind in
    reference_node_locality context node_locality;
    let build_new_node _location =
      Graph.create_node context.graph ~node_kind ~node_locality
    in
    (* Compute the new location which might have changed after folding *)
    let location' =
      match Node_kind.to_location node_kind with
      | None -> location
      | Some location' -> location'
    in
    let ref = (location', node_locality.loc_callstack) in
    let node = NodeTable.memo context.node_table ref build_new_node in
    Some node
  end

let build_var context callstack varinfo =
  let location = Locations.loc_of_varinfo varinfo
  and lval = Var varinfo, NoOffset in
  build_node context callstack location lval

let build_lval context callstack kinstr lval =
  (* If possible, refine the lval to a non-symbolic one *)
  let location = !Db.Value.lval_to_loc kinstr lval in
  match build_node context callstack location lval with
  | None -> None
  | Some node ->
    (* Update the precision information *)
    let node_precision = compute_node_precision kinstr lval in
    Graph.update_node_precision node node_precision;
    Some node

let build_alarm context callstack stmt alarm =
  let node_kind = Alarm (stmt,alarm) in
  let node_locality = build_node_locality callstack node_kind
  and node_precision = Critical in
  Graph.create_node context.graph ~node_precision ~node_kind ~node_locality


exception Too_many_deps of lval

let build_node_deps context node =
  let rec build_writes_deps callstack lval =
    Self.debug ~dkey "computing deps for %a" Cil_printer.pp_lval lval;
    let zone = !Db.Value.lval_to_zone Kglobal lval in
    let writes = Studia.Writes.compute zone
    and add_deps (stmt,effects) =
      match stmt.skind with
      | Instr _ when not effects.Studia.Writes.direct -> ()
      | Instr instr ->
        let callstacks =
          if callstack <> [] &&
             Kernel_function.(equal
                                (find_englobing_kf stmt)
                                (Callstack.top_kf callstack))
          then
            (* slight improvement which only work when there is no recursion
               and which is only usefull because you currently can't have
               all callstacks due to memexec -> in this particular case
               we are sure not to miss the only admissible callstack *)
            [callstack]
          else
            (* Keep only callstacks which are a compatible with the current one *)
            let states = Db.Value.get_stmt_state_callstack ~after:false stmt in
            let callstacks = match states with
              | None -> assert false
              | Some table ->
                let module Table = Value_types.Callstack.Hashtbl in
                Table.fold (fun cs _ acc -> cs :: acc) table []
            in
            (* TODO: missing callstacks filtered by memexec *)
            Callstack.filter_truncate callstacks callstack
        in
        (* Create a dependency for each of them *)
        List.iter (fun cs -> build_instr_deps cs stmt instr) callstacks
      | _ -> assert false
    in
    let count = List.length writes in
    Self.debug ~dkey "%d found" count;
    if count > 20 then
      raise (Too_many_deps lval)
    else
      List.iter add_deps writes

  and build_arg_deps callstack vi =
    assert vi.vformal;
    let kf = Extlib.the (Kernel_function.find_defining_kf vi) in
    let pos = Kernel_function.get_formal_position vi kf in
    let callsites =
      match Callstack.pop callstack with
      | Some (kf',stmt,callstack) ->
        assert (Kernel_function.equal kf' kf);
        [(stmt,callstack)]
      | None ->
        let callsites = Kernel_function.find_syntactic_callsites kf in
        List.map (fun (kf,stmt) -> (stmt,Callstack.init kf)) callsites
    and add_deps (stmt,callstack) =
      match stmt.skind with
      | Instr (Call (_,_,args,_))
      | Instr (Local_init (_, ConsInit (_, args, _), _)) ->
        let exp = List.nth args pos in
        build_exp_deps callstack stmt Data exp
      | _ ->
        assert false (* Callsites can only be Call or ConsInit *)
    in
    List.iter add_deps callsites

  and build_return_deps callstack stmt args kf =
    match Kernel_function.find_return kf with
    | {skind = Return (Some {enode = Lval lval_res},_)} ->
      let callstack = Callstack.push (kf,stmt) callstack in
      build_lval_deps callstack stmt Data lval_res
    | _ -> assert false (* Cil invariant *)
    | exception Kernel_function.No_Statement ->
      (* the function is only a prototype *)
      (* TODO: read assigns instead *)
      List.iter (build_exp_deps callstack stmt Data) args

  and build_call_deps callstack stmt callee args =
    begin match callee.enode with
    | Lval (Var _vi, _offset) -> ()
    | Lval (Mem exp, _offset) ->
      build_exp_deps callstack stmt Callee exp
    | _ ->
      Self.warning "Cannot compute all callee dependencies for %a"
        Cil_printer.pp_stmt stmt;
    end;
    let kinstr = Kstmt stmt in
    let _,set = !Db.Value.expr_to_kernel_function kinstr ~deps:None callee in
    Kernel_function.Hptset.iter (build_return_deps callstack stmt args) set

  and build_alarm_deps callstack stmt alarm =
    let for_exp e =
      build_exp_deps callstack stmt Data e
    in
    let open Alarms in
    match alarm with
    | Division_by_zero e | Index_out_of_bound (e, _) | Invalid_shift (e,_)
    | Overflow (_,e,_,_) | Float_to_int (e,_,_) | Is_nan_or_infinite (e,_)
    | Is_nan (e,_) | Function_pointer (e,_) -> for_exp e
    | Pointer_comparison (opt_e1,e2) -> Extlib.may for_exp opt_e1; for_exp e2
    | Differing_blocks (e1,e2) -> for_exp e1; for_exp e2
    | Memory_access _ | Not_separated _ | Overlap _
    | Uninitialized _ | Dangling _ | Uninitialized_union _ -> ()
      (* TODO: adress depencies inside lval *)
    | Invalid_bool lv -> build_lval_deps callstack stmt Data lv

  and build_instr_deps callstack stmt = function
    | Set (_, exp, _) ->
      build_exp_deps callstack stmt Data exp
    | Call (_, callee, args, _) -> build_call_deps callstack stmt callee args
    | Local_init (dest, ConsInit (f, args, k), loc) ->
      let as_func _dest callee args _loc =
        build_call_deps callstack stmt callee args
      in
      Cil.treat_constructor_as_func as_func dest f args k loc
    | Local_init (_, AssignInit init, _)  ->
      build_init_deps callstack stmt init
    | Asm _ | Skip _ | Code_annot _ -> () (* Cases not returned by Studia *)

  and build_init_deps callstack stmt = function
    | SingleInit exp ->
      build_exp_deps callstack stmt Data exp
    | CompoundInit (_typ, initl) ->
      List.iter (fun (_off,init) -> build_init_deps callstack stmt init) initl

  and build_exp_deps callstack stmt kind exp =
    match exp.enode with
    | Const _
    | SizeOf _ | SizeOfE _ | SizeOfStr _
    | AlignOf _  | AlignOfE _
    | AddrOf _ | StartOf _ -> ()
    | Lval lval ->
      build_lval_deps callstack stmt kind lval
    | UnOp (_,e,_) | CastE (_,e) | Info (e,_) ->
      build_exp_deps callstack stmt kind e
    | BinOp (_,e1,e2,_) ->
      build_exp_deps callstack stmt kind e1;
      build_exp_deps callstack stmt kind e2

  and build_lval_deps callstack stmt kind lval =
    match build_lval context callstack (Kstmt stmt) lval with
    | None -> ()
    | Some dst ->
      let allow_folding = true in
      Graph.create_dependency ~allow_folding context.graph dst kind node

  in
  let callstack = node.node_locality.loc_callstack in
  match node.node_kind with
  | Scalar (vi,_typ,offset) ->
    build_writes_deps callstack (Cil_types.Var vi, offset);
    if vi.vformal then build_arg_deps callstack vi
  | Composite (vi) ->
    build_writes_deps callstack (Cil_types.Var vi, Cil_types.NoOffset);
    if vi.vformal then build_arg_deps callstack vi
  | Scattered (_lval) -> () (* TODO: implements *)
  | Alarm (stmt,alarm) ->
    build_alarm_deps callstack stmt alarm
  | Cluster -> ()



(* --- Graph initialization --- *)

let create () =
  !Db.Value.compute ();
  {
    graph = Graph.create ();
    node_table = NodeTable.create 13;
    file_table = FileTable.create 13;
    callstack_table = CallstackTable.create 13;
    unfolded_bases = BaseSet.empty;
    hidden_bases = BaseSet.empty;
    focus = FunctionMap.empty;
    roots = [];
  }


(* --- Accessors --- *)

let get_graph context =
  context.graph

let get_roots context =
  context.roots


(* --- Mutators --- *)

let unfold_base context vi =
  context.unfolded_bases <- BaseSet.add vi context.unfolded_bases

let fold_base context vi =
  context.unfolded_bases <- BaseSet.remove vi context.unfolded_bases

let hide_base context vi =
  context.hidden_bases <- BaseSet.add vi context.hidden_bases

let unhide_base context vi =
  context.hidden_bases <- BaseSet.add vi context.hidden_bases

let should_auto_explore node =
  match node.node_kind with
  | Scalar _ | Composite _ | Alarm _ -> true
  | Scattered _ | Cluster -> false

let complete_in_depth ~depth context root =
  context.roots <- root :: context.roots;
  (* Breadth first search *)
  let queue : (node * int) Queue.t = Queue.create () in
  Queue.add (root,0) queue;
  while not (Queue.is_empty queue) do
    let (n,d) = Queue.take queue in
    if d < depth then begin
      if not (n.node_deps_computed) && should_auto_explore n then begin
        begin try
            build_node_deps context n;
          with Too_many_deps lval ->
            Self.warning "Too many dependencies for %a ; throwing them out"
              Cil_printer.pp_lval lval;
        end;
        n.node_deps_computed <- true;
      end;
      Graph.iter_pred (fun n' -> Queue.add (n',d+1) queue) context.graph n
    end;
  done

let add_var ?(depth=1) context varinfo =
  let callstack = [] in
  let node = build_var context callstack varinfo in
  Extlib.may (complete_in_depth ~depth context) node

let add_lval ?(depth=1) context kinstr lval =
  let callstack = match kinstr with
    | Kglobal -> []
    | Kstmt stmt -> Callstack.init (Kernel_function.find_englobing_kf stmt)
  in
  let node = build_lval context callstack kinstr lval in
  Extlib.may (complete_in_depth ~depth context) node

let add_alarm ?(depth=1) context stmt alarm =
  let callstack = Callstack.init (Kernel_function.find_englobing_kf stmt) in
  let node = build_alarm context callstack stmt alarm in
  complete_in_depth ~depth context node
