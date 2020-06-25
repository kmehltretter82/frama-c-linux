(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2020                                               *)
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
open Dive_types

let dkey = Self.register_category "build"

exception Too_many_deps

(* --- Utility function --- *)

(* Breaks a list at n-th element into two sublists *)
let rec list_break n l =
  if n <= 0 then ([], l)
  else match l with
    | [] -> ([], [])
    | a :: l ->
      let l1, l2 = list_break (n - 1) l in
      (a :: l1, l2)


(* --- Precision evaluation --- *)

let _fval_contains_maximal_bounds fkind fval =
  let top = Fval.top_finite (Fval.kind fkind) in
  Fval.has_greater_min_bound top fval >= 0 ||
  Fval.has_smaller_max_bound top fval >= 0

let fkind_limits =
  let max_single = float_of_string "0x1.fffffep+127"
  and max_double = float_of_string "0x1.fffffffffffffp+1023" in
  let single_limits = { min = -. max_single ;  max = max_single }
  and double_limits =  { min = -. max_double ;  max = max_double } in
  function
  | FFloat      -> single_limits
  | FDouble     -> double_limits
  | FLongDouble -> assert false

let float_grade_limits =
  let single = float_of_string "0x1p+120"
  and double = float_of_string "0x1p+960"
  and long_double = float_of_string "0x1p+15360"
  in function
    | FFloat      -> single
    | FDouble     -> double
    | FLongDouble -> long_double

let is_large_float_range fkind (min,max) =
  let limit = float_grade_limits fkind in
  if (min < 0.0) = (max < 0.0) then (* if bounds have same sign *)
    max -. min >= limit
  else
    min <= -.limit || max >= limit

let float_grade fkind (min,max) =
  if min = max then
    Singleton
  else if is_large_float_range fkind (min,max) then
    Wide
  else
    Normal

let ikind_limits ikind =
  let open Cil in
  let bits = bitsSizeOfInt ikind in
  if isSigned ikind then
    { min=min_signed_number bits; max=max_signed_number bits }
  else
    { min=Integer.zero; max=max_unsigned_number bits }

let int_grade_limits ikind =
  let bits = Cil.bitsSizeOfInt ikind in
  Integer.(pred (two_power_of_int (bits - bits / 8)))

let is_large_int_range ikind (l,u) =
  let limit = int_grade_limits ikind in
  if Integer.(lt l zero) = Integer.(lt u zero) then (* if bounds have same sign *)
    Integer.(ge (sub u l) limit)
  else
    Integer.(le l (neg limit)) || Integer.(ge u limit)

let int_grade ikind (min,max) =
  if min = max then
    Singleton
  else if is_large_int_range ikind (min,max) then
    Wide
  else
    Normal


let update_node_values node kinstr lval =
  let typ = Cil.typeOfLval lval in
  let state = Db.Value.get_state kinstr in
  let _,cvalue = !Db.Value.eval_lval None state lval in
  try
    let ival = Cvalue.V.project_ival cvalue in
    match typ with
    | TInt (ikind,_) ->
      let size =  Integer.of_int (Cil.bitsSizeOfInt ikind)
      and signed = Cil.isSigned ikind in
      let ival = Ival.reinterpret_as_int ~size ~signed ival in
      let min, max = match Ival.min_and_max ival with
        | Some min, Some max -> min, max
        | _, _ -> assert false (* ival have been reinterpreted *)
      in
      Imprecision_graph.update_node_int_values node {
        values_interval = {min;max};
        values_limits = ikind_limits ikind;
        values_grade = int_grade ikind (min,max)
      }

    | TFloat (fkind,_) ->
      begin match Ival.min_and_max_float ival with
        | None, _can_be_nan -> ()
        | Some (min, max), _can_be_nan ->
          let min = Fval.F.to_float min and max = Fval.F.to_float max in
          Imprecision_graph.update_node_float_values node {
            values_interval = {min;max};
            values_limits = fkind_limits fkind;
            values_grade = float_grade fkind (min,max);
          }
      end
    | _ -> ()
  with Cvalue.V.Not_based_on_null -> ()


(* --- Locations handling --- *)

let get_loc_filename loc =
  Filepath.(Normalized.to_pretty_string (fst loc).pos_path)

let is_foldable_type typ =
  match Cil.unrollType typ with
  | TArray _ | TComp _ -> true
  | TVoid _ | TInt _ | TEnum _ | TFloat _ | TPtr _ | TFun _
  | TBuiltin_va_list _ -> false
  | TNamed _ -> assert false (* the type have been unrolled *)

exception NoMatchingOffset

let cell_to_scalar typ vi offset =
  (* TODO: exceptions must be shown to the user somehow *)
  try
    let matching = Bit_utils.MatchType typ in
    let offset', _ = Bit_utils.find_offset vi.vtype ~offset matching in
    Scalar (vi, typ, offset')
  with Bit_utils.NoMatchingOffset -> raise NoMatchingOffset

exception NotACell

let enumerate_cells ~is_folded_base ~limit lval kinstr =
  (* TODO: non-variable bases must be shown to the user somehow *)
  (* TODO: exceptions must be shown to the user somehow *)
  (* If possible, refine the lval to a non-symbolic one *)
  let location = !Db.Value.lval_to_loc kinstr lval
  and typ = Cil.typeOfLval lval in
  let open Locations in
  let add (acc,count) node_kind =
    if count > limit then
      raise Too_many_deps;
    (node_kind :: acc, count+1)
  in
  let add_base base ival (acc,count) =
    match base with
    | Base.Var (vi,_) ->
      begin
        if is_foldable_type vi.vtype && is_folded_base vi then
          add (acc,count) (Composite (vi))
        else
          let add_cells offset (acc,count) =
            add (acc,count) (cell_to_scalar typ vi offset)
          in
          try
            Ival.fold_int add_cells ival (acc,count)
          with Abstract_interp.Error_Top -> raise NotACell
      end
    | _ -> raise NotACell
  in
  try
    fst (Location_Bits.fold_i add_base location.loc ([],0))
  with Abstract_interp.Error_Top | NoMatchingOffset -> raise NotACell

let build_node_kind ~is_folded_base lval kinstr =
  match enumerate_cells ~is_folded_base ~limit:1 lval kinstr with
  | [node_kind] -> node_kind
  | _ -> Scattered (lval, kinstr)
  | exception NotACell -> Scattered (lval, kinstr)

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
    (Node_kind) (Callstack)
    (struct let module_name = "Build.NodeRef" end)

module Graph = Imprecision_graph
module Index = Datatype.Int.Hashtbl
module NodeTable = FCHashtbl.Make (NodeRef)
module BaseSet = Cil_datatype.Varinfo.Set
module FunctionMap = Kernel_function.Map

type t = {
  mutable graph: Graph.t;
  mutable vertex_table: node Index.t; (* node_key -> node *)
  mutable node_table: node NodeTable.t; (* node_kind * callstack -> node *)
  mutable unfolded_bases: BaseSet.t;
  mutable hidden_bases: BaseSet.t;
  mutable focus: bool FunctionMap.t;
  mutable max_dep_fetch_count: int;
  mutable roots: node list;
  mutable graph_diff: graph_diff;
}

let is_folded context vi =
  not (BaseSet.mem vi context.unfolded_bases)

let is_hidden context node_kind =
  match Node_kind.get_base node_kind with
  | Some vi when BaseSet.mem vi context.hidden_bases -> true
  | _ -> false

let find_node context node_key =
  Index.find context.vertex_table node_key

let update_node context node =
  if
    not (List.exists (Graph.Node.equal node) context.graph_diff.added_nodes)
  then
    context.graph_diff <- {
      context.graph_diff with
      added_nodes = node :: context.graph_diff.added_nodes
    }

let add_node context ~node_kind ~node_locality =
  let node_ref = (node_kind, node_locality.loc_callstack) in
  let add_new _ =
    let node = Graph.create_node context.graph ~node_kind ~node_locality in
    node.node_hidden <- is_hidden context node.node_kind;
    Index.add context.vertex_table node.node_key node;
    update_node context node;
    node
  in
  NodeTable.memo context.node_table node_ref add_new

let remove_node context node =
  let node_ref = (node.node_kind, node.node_locality.loc_callstack) in
  Graph.remove_node context.graph node;
  Index.remove context.vertex_table node.node_key;
  NodeTable.remove context.node_table node_ref;
  context.graph_diff <- {
    context.graph_diff with
    removed_nodes = node :: context.graph_diff.removed_nodes
  }


(* --- Graph building --- *)

let add_or_update_node context callstack node_kind =
  let node_locality = build_node_locality callstack node_kind in
  add_node context ~node_kind ~node_locality

let build_node context callstack lval kinstr =
  let is_folded_base = is_folded context in
  let node_kind = build_node_kind ~is_folded_base lval kinstr in
  add_or_update_node context callstack node_kind

let build_all_scattered_node context callstack kinstr lval =
  let is_folded_base = is_folded context in
  try
    let cells = enumerate_cells ~is_folded_base ~limit:20 lval kinstr in
    let add node_kind =
      let node = add_or_update_node context callstack node_kind in
      let new_lval = Extlib.the (Node_kind.to_lval node_kind) in
      update_node_values node kinstr new_lval;
      node
    in
    List.map add cells
  with NotACell ->
    Self.warning "Unable to enumerate cells for %a"
      Cil_printer.pp_lval lval;
    []

let build_var context callstack varinfo =
  let lval = Var varinfo, NoOffset in
  build_node context callstack lval Kglobal

let build_lval context callstack kinstr lval =
  let node = build_node context callstack lval kinstr in
  update_node_values node kinstr lval;
  node

let build_alarm context callstack stmt alarm =
  let node_kind = Alarm (stmt,alarm) in
  let node_locality = build_node_locality callstack node_kind in
  add_node context ~node_kind ~node_locality

let build_node_deps context node =
  let rec build_lval_write_deps callstack kinstr lval =
    let zone = !Db.Value.lval_to_zone kinstr lval in
    build_write_deps callstack zone

  and build_write_deps callstack zone =
    let writes = match node.node_writes_computation with
      | Done -> []
      | Partial writes -> writes
      | NotDone ->
        Self.debug ~dkey "computing deps for %a" Node_kind.pretty node.node_kind;
        let result = Studia.Writes.compute zone in
        let is_direct (_,{Studia.Writes.direct}) = direct in
        let writes = Extlib.filter_map is_direct fst result in
        Self.debug ~dkey "%d found" (List.length writes);
        node.node_writes_stmts <- writes;
        writes
    and add_deps = function
      | { skind=Instr instr } as stmt ->
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
      | _ -> assert false (* Studia invariant *)
    in
    let sub,rest = list_break context.max_dep_fetch_count writes in
    List.iter add_deps sub;
    node.node_writes_computation <- if rest = [] then Done else Partial rest

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
    | {skind = Return (Some {enode = Lval lval_res},_)} as return_stmt ->
      let callstack = Callstack.push (kf,stmt) callstack in
      build_lval_deps callstack return_stmt Data lval_res
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
    | Is_nan (e,_) | Function_pointer (e,_) | Invalid_pointer e -> for_exp e
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
    let kinstr = Kstmt stmt in
    let dst = build_lval context callstack kinstr lval in
    Graph.create_dependency ~allow_folding:true
      context.graph kinstr dst kind node

  and build_scattered_deps callstack kinstr lval =
    let nodes = build_all_scattered_node context callstack kinstr lval in
    let kind = Composition in
    let add_dep dst =
      Graph.create_dependency ~allow_folding:true
        context.graph kinstr dst kind node
    in
    List.iter add_dep nodes

  in
  update_node context node;
  let callstack = node.node_locality.loc_callstack in
  begin match node.node_kind with
    | Scalar (vi,_typ,offset) ->
      let lval = (Cil_types.Var vi, offset) in
      build_lval_write_deps callstack Kglobal lval
    | Composite (vi) ->
      let lval = (Cil_types.Var vi, Cil_types.NoOffset) in
      build_lval_write_deps callstack Kglobal lval
    | Scattered (lval,kinstr) ->
      build_scattered_deps callstack kinstr lval
    | Alarm (stmt,alarm) ->
      build_alarm_deps callstack stmt alarm
  end;
  begin match Node_kind.get_base node.node_kind with
    (* TODO refine formal dependency computation for non-scalar formals *)
    | Some vi when vi.vformal -> build_arg_deps callstack vi
    | _ -> ()
  end


(* --- Graph initialization --- *)

let create () =
  !Db.Value.compute ();
  {
    graph = Graph.create ();
    vertex_table = Index.create 13;
    node_table = NodeTable.create 13;
    unfolded_bases = BaseSet.empty;
    hidden_bases = BaseSet.empty;
    focus = FunctionMap.empty;
    max_dep_fetch_count = 10;
    roots = [];
    graph_diff = { last_root = None ; added_nodes=[] ; removed_nodes=[] };
  }

let clear context =
  context.graph <- Graph.create ();
  context.vertex_table <- Index.create 13;
  context.node_table <- NodeTable.create 13;
  context.focus <- FunctionMap.empty;
  context.max_dep_fetch_count <- 10;
  context.roots <- [];
  context.graph_diff <- { last_root = None ; added_nodes=[] ; removed_nodes=[] }


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

let explore ~depth context root =
  context.graph_diff <- { context.graph_diff with last_root = Some root };
  let should_auto_explore node =
    let is_root = Graph.Node.equal node root (* the root is always explored *)
    and is_intersting_kind = match node.node_kind with
      | Scalar _ | Composite _ | Alarm _ -> true
      | Scattered _ -> false
    in
    is_root || (not node.node_hidden && is_intersting_kind)
  in
  (* Breadth first search *)
  let queue : (node * int) Queue.t = Queue.create () in
  Queue.add (root,0) queue;
  while not (Queue.is_empty queue) do
    let (n,d) = Queue.take queue in
    if d < depth then begin
      if n.node_writes_computation <> Done && should_auto_explore n then
        begin
          begin try
              build_node_deps context n;
            with Too_many_deps ->
              (* TODO: give a mean to explore more dependencies *)
              Self.warning "Too many dependencies for %a ; throwing them out"
                Node_kind.pretty n.node_kind;
          end;
        end;
      Graph.iter_pred (fun n' -> Queue.add (n',d+1) queue) context.graph n
    end;
  done

let complete context root =
  context.roots <- root :: context.roots;
  root

let add_var context varinfo =
  let callstack = [] in
  let node = build_var context callstack varinfo in
  complete context node

let add_lval context kinstr lval =
  let callstack = match kinstr with
    | Kglobal -> []
    | Kstmt stmt -> Callstack.init (Kernel_function.find_englobing_kf stmt)
  in
  let node = build_lval context callstack kinstr lval in
  complete context node

let add_alarm context stmt alarm =
  let callstack = Callstack.init (Kernel_function.find_englobing_kf stmt) in
  let node = build_alarm context callstack stmt alarm in
  complete context node

let add_annotation context stmt annot =
  (* Only do something for alarms notations *)
  Extlib.opt_map (add_alarm context stmt) (Alarms.find annot)

let add_instr context stmt = function
  | Set (lval, _, _)
  | Call (Some lval, _, _, _) -> Some (add_lval context (Kstmt stmt) lval)
  | Local_init (vi, _, _) -> Some (add_var context vi)
  | Code_annot (annot, _) -> add_annotation context stmt annot
  | _ -> None (* Do nothing for any other instruction *)

let add_stmt context stmt =
  match stmt.skind with
  | Instr instr -> add_instr context stmt instr
  | _ -> None (* Do nothing for any other statements *)

let add_property context = function
  | Property.IPCodeAnnot { ica_stmt ; ica_ca } ->
    add_annotation context ica_stmt ica_ca
  | _ -> None (* Do nothing fo any other property *)

let add_localizable context = function
  | Printer_tag.PLval (_kf, kinstr, lval) -> Some (add_lval context kinstr lval)
  | PVDecl (_kf, _kinstr, varinfo) -> Some (add_var context varinfo)
  | PIP (prop) -> add_property context prop
  | PStmt (_kf, stmt) | PStmtStart (_kf, stmt) -> add_stmt context stmt
  | _ -> None (* Do nothing for any other localizable *)

let show _context node =
  node.node_hidden <- false

let hide context node =
  if not node.node_hidden then
    begin
      let g = get_graph context in
      (* Set the node as hidden *)
      node.node_hidden <- true;
      (* Remove incomming edges *)
      let incomming_edges = Graph.pred_e g node in
      List.iter (Graph.remove_dependency g) incomming_edges;
      (* Dependencies are not there anymore *)
      node.node_writes_computation <- NotDone;
      node.node_writes_stmts <- [];
      (* Notify node update *)
      update_node context node
    end

let remove_disconnected context =
  let l = Graph.find_independant_nodes context.graph context.roots in
  List.iter (remove_node context) l

let hide_and_reduce context node =
  hide context node;
  remove_disconnected context

let reduce_to_horizon ({ graph } as context) range new_root =
  (* Reduce to one root *)
  context.roots <- [ new_root ];
  (* List visible nodes *)
  let bacward_nodes =
    Imprecision_graph.bfs ~iter_succ:Imprecision_graph.iter_pred
      ?limit:range.backward graph context.roots
  and forward_nodes =
    Imprecision_graph.bfs ~iter_succ:Imprecision_graph.iter_succ
      ?limit:range.forward graph context.roots
  in
  (* Table of visible nodes *)
  let module Table = Hashtbl.Make (Imprecision_graph.Node) in
  let visible = Table.create 13 in
  let is_visible = Table.mem visible in
  List.iter (fun n -> Table.add visible n true) (bacward_nodes @ forward_nodes);
  (* Find nodes to hide / remove *)
  let update node =
    if not (is_visible node) then
      if List.exists is_visible (Imprecision_graph.succ graph node) then
        hide context node
      else
        remove_node context node
  in
  Graph.iter_vertex update graph


let take_last_differences context =
  let pp_node fmt n = Format.pp_print_int fmt n.node_key in
  let pp_node_list = Pretty_utils.pp_list ~sep:",@, " pp_node in
  let diff = context.graph_diff in
  Self.debug ~dkey "root: %a,@, added: %a,@, subbed: %a"
    (Pretty_utils.pp_opt pp_node) diff.last_root
    pp_node_list diff.added_nodes
    pp_node_list diff.removed_nodes;
  context.graph_diff <- {
    last_root = None ;
    added_nodes=[] ;
    removed_nodes=[]
  };
  diff
