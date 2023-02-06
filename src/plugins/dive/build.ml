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

open Cil_types
open Dive_types

module Graph = Dive_graph
module Seq =
struct
  include Stdlib.Seq
  include Transitioning.Seq
end

let dkey = Self.register_category "build"


(* --- Lval enumeration --- *)

module EnumLvals =
struct
  let visitor () =
    object
      inherit Visitor.frama_c_inplace
      val mutable acc = []
      method get_acc = acc
      method! vexpr expr =
        match expr.enode with
        | Lval lval -> acc <- lval :: acc; Cil.SkipChildren
        | UnOp _ | BinOp _ | CastE _ -> Cil.DoChildren
        | _ -> Cil.SkipChildren
    end

  (* Returns a list of lvalues required to compute the address of [lval]. *)
  let in_lval lval =
    let vis = visitor () in
    ignore (Visitor.visitFramacLval (vis :> Visitor.frama_c_inplace) lval);
    List.rev vis#get_acc

  let in_exp exp =
    let vis = visitor () in
    ignore (Visitor.visitFramacExpr (vis :> Visitor.frama_c_inplace) exp);
    List.rev vis#get_acc

  let in_init vi init =
    let vis = visitor () in
    ignore (Visitor.visitFramacInit (vis :> Visitor.frama_c_inplace) vi NoOffset init);
    List.rev vis#get_acc

  let in_alarm = function
    | Alarms.Division_by_zero e | Index_out_of_bound (e, _) | Invalid_shift (e,_)
    | Overflow (_,e,_,_) | Float_to_int (e,_,_) | Is_nan_or_infinite (e,_)
    | Is_nan (e,_) | Function_pointer (e,_) | Invalid_pointer e ->
      in_exp e
    | Pointer_comparison (opt_e1,e2) ->
      Option.fold ~none:[] ~some:in_exp opt_e1 @ in_exp e2
    | Differing_blocks (e1,e2) ->
      in_exp e1 @ in_exp e2
    | Memory_access (lval, _) -> in_lval lval
    | Not_separated _ | Overlap _
    | Uninitialized _ | Dangling _ -> []
    | Invalid_bool lv -> [lv]
end


(* --- Evaluation from analysis results --- *)

module Eval =
struct
  open Eva.Results

  let at_start_of = at_start_of
  let after = after
  let after_kinstr = function
    | Kglobal -> at_start (* After global initialization *)
    | Kstmt stmt -> after stmt

  let to_kf_list kinstr callee =
    before_kinstr kinstr |> eval_callee callee |>
    Result.value ~default:[]

  let to_cvalue request lval =
    eval_lval lval request |> as_cvalue

  let to_location kinstr lval =
    before_kinstr kinstr |> eval_address lval |> as_location

  let to_zone kinstr lval =
    before_kinstr kinstr |> eval_address lval |> as_zone

  let to_callstacks stmt =
    before stmt |> callstacks

  let is_tainted request lval =
    let zone = eval_address lval request |> as_zone in
    is_tainted zone request |> Result.to_option

  let writes kinstr lval =
    let zone = to_zone kinstr lval in
    Self.debug ~dkey "computing writes for %a" Cil_printer.pp_lval lval;
    let writes = Studia.Writes.compute zone in
    Self.debug ~dkey "%d found" (List.length writes);
    writes

  let reads kinstr lval =
    let zone = to_zone kinstr lval in
    Self.debug ~dkey "computing reads for %a" Cil_printer.pp_lval lval;
    let reads = Studia.Reads.compute zone in
    Self.debug ~dkey "%d found" (List.length reads);
    reads

  let does_lval_read_zone zone stmt lval =
    let zone' = to_zone (Kstmt stmt) lval in
    Locations.Zone.intersects zone' zone

  let does_exp_read_zone zone stmt exp =
    List.exists (does_lval_read_zone zone stmt) (EnumLvals.in_exp exp)

  let does_init_read_zone zone stmt vi init  =
    List.exists (does_lval_read_zone zone stmt) (EnumLvals.in_init vi init)
end


(* --- Precision evaluation --- *)

(* For folded bases, lval may be strictly included in the node zone *)
let update_node_values context node ?(lval=Node_kind.to_lval node.node_kind) rq =
  match lval with
  | None -> () (* can't evaluate node *)
  | Some lval ->
    let typ = Cil.typeOfLval lval
    and cvalue = Eval.to_cvalue rq lval
    and taint = Eval.is_tainted rq lval in
    Context.update_node_values context node ~typ ~cvalue ~taint


(* --- Locations handling --- *)

let get_loc_filename loc =
  Filepath.(Normalized.to_pretty_string (fst loc).pos_path)

let is_foldable_type typ =
  match Cil.unrollType typ with
  | TArray _ | TComp _ -> true
  | TVoid _ | TInt _ | TEnum _ | TFloat _ | TPtr _ | TFun _
  | TBuiltin_va_list _ -> false
  | TNamed _ -> assert false (* the type have been unrolled *)


let enumerate_cells ~is_folded_base lval kinstr =
  (* If possible, refine the lval to a non-symbolic one *)
  let typ = Cil.typeOfLval lval in
  let location = Eval.to_location kinstr lval in
  let open Locations in
  let map_base (base,ival) =
    match base with
    | Base.Var (vi,_) | Allocated (vi,_,_) ->
      begin
        if is_foldable_type vi.vtype && is_folded_base vi then
          Seq.return (Composite (vi))
        else
          let map_offset offset =
            let matching = Bit_utils.MatchType typ in
            let offset', _ = Bit_utils.find_offset vi.vtype ~offset matching in
            Scalar (vi, typ, offset')
          in
          try
            Ival.to_int_seq ival |> Seq.map map_offset
          with Abstract_interp.Error_Top | Bit_utils.NoMatchingOffset ->
            (* fallback to composite node *)
            Seq.return (Composite (vi))
      end
    | CLogic_Var _ -> Seq.return (Error "logic variables not supported")
    | Null -> Seq.return AbsoluteMemory
    | String (i,cs) -> Seq.return (String (i, cs))
  in
  try
    Location_Bits.to_seq_i location.loc |> Seq.flat_map map_base
  with Abstract_interp.Error_Top ->
    Seq.return (Unknown (lval, kinstr))

let build_node_kind ~is_folded_base lval kinstr =
  match lval with
  | Var vi, offset ->
    (* Build a scalar node even if kinstr is dead *)
    Scalar (vi, Cil.typeOfLval lval, offset)
  | Mem _, _ ->
    let cells_seq = enumerate_cells ~is_folded_base lval kinstr in
    match cells_seq () with
    | Seq.Cons (node_kind, seq) when Seq.is_empty seq -> node_kind
    | _ ->
      match kinstr with
      | Kglobal -> assert false (* global initializations can always be resolved to one cell  *)
      | Kstmt stmt -> Scattered (lval, stmt)

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

let find_compatible_callstacks stmt callstack =
  let kf = Kernel_function.find_englobing_kf stmt in
  if callstack = [] (* Globals variables *)
  then [Callstack.init kf] (* Default *)
  else if Kernel_function.equal kf (Callstack.top_kf callstack)
  then
    (* slight improvement which only work when there is no recursion
       and which is only usefull because you currently can't have
       all callstacks due to memexec -> in this particular case
       we are sure not to miss the only admissible callstack *)
    [callstack]
  else
    (* Keep only callstacks which are a compatible with the current one *)
    let callstacks = Eval.to_callstacks stmt in
    (* TODO: missing callstacks filtered by memexec *)
    let make_compatible cs =
      Callstack.truncate_to_sub cs callstack |>
      Option.value ~default:(Callstack.init kf)
    in
    let result = List.map make_compatible callstacks in
    List.sort_uniq Callstack.compare result (* Remove duplicates *)


(* --- Graph building --- *)

let add_or_update_node context callstack node_kind =
  let node_locality = build_node_locality callstack node_kind in
  let node = Context.add_node context ~node_kind ~node_locality in
  begin match node_kind with (* Some nodes don't have read or write deps *)
    | Alarm _ ->
      node.node_reads_computation <- Done
    | Unknown _ | Const _ | String _ ->
      node.node_writes_computation <- Done
    | Error _ ->
      node.node_reads_computation <- Done;
      node.node_writes_computation <- Done
    | _ -> ()
  end;
  node

let build_node context callstack lval kinstr =
  let is_folded_base = Context.is_folded context in
  let node_kind = build_node_kind ~is_folded_base lval kinstr in
  add_or_update_node context callstack node_kind

let build_var context callstack varinfo =
  let lval = Var varinfo, NoOffset in
  build_node context callstack lval Kglobal

let build_lval context callstack kinstr lval =
  let node = build_node context callstack lval kinstr in
  update_node_values context ~lval:(Some lval) node (Eval.after_kinstr kinstr);
  node

let build_const context callstack exp =
  add_or_update_node context callstack (Const exp)

let build_alarm context callstack stmt alarm =
  let node_kind = Alarm (stmt,alarm) in
  let node_locality = build_node_locality callstack node_kind in
  Context.add_node context ~node_kind ~node_locality


(* --- Writes --- *)

let compatible_writes callstack = function
| Studia.Writes.CallIndirect _ -> None (* Ignore indirect writes *)
| Assign _ | CallDirect _ | GlobalInit _ as w -> Some w
| FormalInit (vi, _callsites) as w ->
  match Callstack.pop callstack with
  | Some (kf,stmt,_callstack) ->
    Some (Studia.Writes.FormalInit (vi, [(kf,[stmt])])) (* keep the only callsite compatible with the current callstack *)
  | None -> Some w

let write_to_kinstr = function
| Studia.Writes.CallIndirect s | Assign s | CallDirect s -> Kstmt s
| GlobalInit _ | FormalInit _ -> Kglobal

(* returns true if the callsite (kf,stmt) *)

type deps_builder = unit Seq.t

let build_node_writes context node =
  let is_folded_base = Context.is_folded context in

  let rec build_write_deps ~callstack kinstr lval : deps_builder =
    let add_deps origin =
      match origin with
      | Studia.Writes.CallIndirect _ ->
        Seq.empty (* Ignore indirect writes *)

      | Assign stmt | CallDirect stmt ->
        let instr = match stmt.skind with
          | Instr instr -> instr
          | _ -> assert false (* Studia invariant *)
        in
        (* Update the values at the light of new discovered write *)
        update_node_values context node (Eval.after stmt);
        (* Add dependencies for each callstack *)
        List.to_seq (find_compatible_callstacks stmt callstack) |>
        Seq.flat_map
          (fun cs -> build_instr_deps ~callstack:cs ~origin stmt instr)

      | GlobalInit (vi, initinfo) as origin ->
        let init = match initinfo.init with
          | None -> SingleInit (Cil.zero ~loc:vi.vdecl)
          | Some init -> init
        in
        build_init_deps ~callstack ~origin vi init

      | FormalInit (vi, callsites) as origin ->
        let kf = Option.get (Kernel_function.find_defining_kf vi) in
        let pos = Kernel_function.get_formal_position vi kf in
        let add_deps stmt =
          match stmt.skind with
          | Instr
              (Call (_,_,args,_) |
              (Local_init (_, ConsInit (_, args, _), _))) ->
            let exp = List.nth args pos in
            let callstack =
              match Callstack.pop callstack with
              | Some (_kf,_stmt,callstack') -> callstack'
              | None -> Callstack.init kf
            in
            build_exp_deps ~origin ~callstack Data exp
          | _ ->
            assert false (* Callsites can only be Call or ConsInit *)
        in
        (* Evaluate the parameter values at the start of its defining function *)
        update_node_values context node (Eval.at_start_of kf);
        let callsites = List.concat_map snd callsites in
        Seq.flat_map add_deps (List.to_seq callsites)
    in
    let writes = Eval.writes kinstr lval in
    let writes = List.filter_map (compatible_writes callstack) writes in
    Context.set_node_writes context node writes;
    Seq.flat_map add_deps (List.to_seq writes)

  and build_alarm_deps ~callstack stmt alarm : deps_builder =
    let lvals = EnumLvals.in_alarm alarm in
    let origin = Studia.Writes.Assign stmt in
    build_lvals_deps ~origin ~callstack Data lvals

  and build_instr_deps ~callstack ~origin stmt instr : deps_builder =
    (* Add dependencies found in the instruction *)
    match instr with
    | Set (_, exp, _) ->
      build_exp_deps ~origin ~callstack Data exp
    | Call (_, callee, args, _) ->
      build_call_deps ~callstack ~origin stmt callee args
    | Local_init (dest, ConsInit (f, args, k), loc) ->
      let as_func _dest callee args _loc =
        build_call_deps ~callstack ~origin stmt callee args
      in
      Cil.treat_constructor_as_func as_func dest f args k loc
    | Local_init (vi, AssignInit init, _)  ->
      build_init_deps ~origin ~callstack vi init
    | Asm _ | Skip _ | Code_annot _ -> Seq.empty (* Cases not returned by Studia *)

  and build_return_deps ~callstack call_stmt args kf : deps_builder =
    match Kernel_function.find_return kf with
    | {skind = Return (Some {enode = Lval lval_res},_)} as return_stmt ->
      let callstack = Callstack.push (kf,call_stmt) callstack in
      let origin = Studia.Writes.Assign return_stmt in
      build_lval_deps ~origin ~callstack Data lval_res
    | {skind = Return (None, _)} -> Seq.empty (* return void *)
    | _ -> assert false (* Cil invariant *)
    | exception Kernel_function.No_Statement ->
      (* the function is only a prototype *)
      (* TODO: read assigns instead *)
      let origin = Studia.Writes.Assign call_stmt in
      List.to_seq args |>
      Seq.flat_map (build_exp_deps ~origin ~callstack Data)

  and build_call_deps ~callstack ~origin stmt callee args : deps_builder =
    let callee_deps = match callee.enode with
      | Lval (Var _vi, _offset) -> Seq.empty
      | Lval (Mem exp, _offset) ->
        build_exp_deps ~origin ~callstack Callee exp
      | _ ->
        Self.warning "Cannot compute all callee dependencies for %a"
          Cil_printer.pp_stmt stmt;
        Seq.empty
    and return_deps =
      List.to_seq (Eval.to_kf_list (Kstmt stmt) callee) |>
      Seq.flat_map (build_return_deps ~callstack stmt args)
    in
    Seq.append callee_deps return_deps

  and build_init_deps ~origin ~callstack vi init : deps_builder =
    let lvals = EnumLvals.in_init vi init in
    let exp =
      match init with
      | CompoundInit _ -> None (* Do not generate nodes for Compounds for now *)
      | SingleInit exp -> Some exp
    in
    build_lvals_deps ~origin ~callstack Data ?exp lvals

  and build_exp_deps ~origin ~callstack kind exp : deps_builder =
    let lvals = EnumLvals.in_exp exp in
    build_lvals_deps ~origin ~callstack kind ~exp lvals

  and build_lvals_deps ~origin ~callstack kind ?exp lvals : deps_builder =
    if lvals <> [] then
      List.to_seq lvals |>
      Seq.flat_map (build_lval_deps ~origin ~callstack kind)
    else
      Option.fold exp ~none:Seq.empty
        ~some:(build_const_deps ~origin ~callstack kind)

  and build_lval_deps ~origin ~callstack kind lval : deps_builder =
    let dst = build_lval context callstack (write_to_kinstr origin) lval in
    Seq.return (Context.add_dep context ~origin ~kind dst node)

  and build_const_deps ~callstack ~origin kind exp : deps_builder =
    let dst = build_const context callstack exp in
    Seq.return (Context.add_dep context ~origin ~kind dst node)

  and build_scattered_deps ~callstack stmt lval : deps_builder =
    let add_cell node_kind =
      let dst = add_or_update_node context callstack node_kind in
      update_node_values context node (Eval.after stmt);
      let origin = Studia.Writes.Assign stmt in
      Context.add_dep context ~origin ~kind:Composition dst node
    in
    enumerate_cells ~is_folded_base lval (Kstmt stmt) |> Seq.map add_cell
  in

  let callstack = node.node_locality.loc_callstack in
  match node.node_kind with
  | Scalar (vi,_typ,offset) ->
    build_write_deps ~callstack Kglobal (Cil_types.Var vi, offset)
  | Composite (vi) ->
    build_write_deps ~callstack Kglobal (Cil_types.Var vi, Cil_types.NoOffset)
  | Scattered (lval,stmt) ->
    build_scattered_deps ~callstack stmt lval
  | Alarm (stmt,alarm) ->
    build_alarm_deps ~callstack stmt alarm
  | Unknown _ | AbsoluteMemory | String _ | Const _ | Error _ ->
    Seq.empty


(* --- Reads --- *)

let compatible_reads = function
| Studia.Reads.Indirect _ -> None
| Direct stmt -> Some stmt

let build_node_reads context node =
  let rec build_reads_deps callstack kinstr lval : deps_builder =
    let add_deps stmt =
      let zone = Some (Eval.to_zone kinstr lval) in
      List.to_seq (find_compatible_callstacks stmt callstack) |>
      Seq.flat_map (fun cs -> build_stmt_deps cs zone stmt)
    in
    Eval.reads kinstr lval |> List.to_seq |>
    Seq.filter_map compatible_reads |>
    Seq.flat_map add_deps

  and exp_contains_read zone stmt exp =
    match zone with
    | None -> true
    | Some zone' ->
      Eval.does_exp_read_zone zone' stmt exp

  and init_contains_read zone stmt vi init =
    match zone with
    | None -> true
    | Some zone' ->
      Eval.does_init_read_zone zone' stmt vi init

  and build_stmt_deps callstack zone stmt =
    match stmt.skind with
    | Instr instr -> build_instr_deps callstack zone stmt instr
    | Return (Some exp,_)
      when exp_contains_read zone stmt exp ->
      build_return_deps callstack stmt
    | _ -> Seq.empty

  and build_instr_deps callstack zone stmt = function
    | Set (lval, exp, _)
      when exp_contains_read zone stmt exp ->
      build_lval_deps ~callstack stmt lval
    | Local_init (dest, ConsInit (f, args, k), loc) ->
      let as_func _dest callee args _loc =
        build_call_deps callstack zone stmt callee args
      in
      Cil.treat_constructor_as_func as_func dest f args k loc
    | Local_init (vi, AssignInit init, _)
      when init_contains_read zone stmt vi init ->
      build_var_deps ~callstack stmt vi
    | Call (_, callee, args, _) ->
      build_call_deps callstack zone stmt callee args
    | _ -> Seq.empty

  and build_return_deps callstack stmt =
    let kf = Kernel_function.find_englobing_kf stmt in
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
      | Instr (Call (None,_,_,_)) -> Seq.empty
      | Instr (Call (Some lval,_,_,_)) ->
        build_lval_deps ~callstack stmt lval
      | Instr (Local_init (vi,_,_)) ->
        build_var_deps ~callstack stmt vi
      | _ ->
        assert false (* Callsites can only be Call or ConsInit *)
    in
    Seq.flat_map add_deps (List.to_seq callsites);

  and build_call_deps callstack zone stmt callee args =
    List.to_seq (Eval.to_kf_list (Kstmt stmt) callee) |>
    Seq.flat_map (build_args_deps callstack zone stmt args)

  and build_args_deps callstack zone stmt args callee_kf =
    let callstack = Callstack.push (callee_kf,stmt) callstack in
    let formals = Kernel_function.get_formals callee_kf in
    (* For Frama_C_show_each and functions called through pointers, there may
       be more arguments than formal parameters declared. *)
    let used_args = Extlib.list_first_n (List.length formals) args in
    List.to_seq (List.combine used_args formals) |>
    Seq.flat_map (build_arg_dep callstack stmt zone)

  and build_arg_dep callstack stmt zone (arg,formal) =
    if exp_contains_read zone stmt arg
    then build_var_deps ~callstack stmt formal
    else Seq.empty

  and build_lval_deps ~callstack stmt lval =
    let src = build_lval context callstack (Kstmt stmt) lval in
    let origin = Studia.Writes.Assign stmt in
    Seq.return (Context.add_dep context ~origin ~kind:Data node src)

  and build_var_deps ~callstack stmt vi =
    build_lval_deps ~callstack stmt (Cil.var vi)

  in
  let callstack = node.node_locality.loc_callstack in
  match node.node_kind with
  | Scalar (vi,_typ,offset) ->
    build_reads_deps callstack Kglobal (Cil_types.Var vi, offset)
  | Composite (vi) ->
    build_reads_deps callstack Kglobal (Cil_types.Var vi, Cil_types.NoOffset)
  | Scattered (_lval,stmt) ->
    build_stmt_deps callstack None stmt
  | Alarm _ | Unknown _ | AbsoluteMemory | Const _ | String _ | Error _ ->
    Seq.empty


(* --- Exploration --- *)

let should_explore node root =
  match node.node_kind with
  | Scattered _ -> Graph.Node.equal node root
  | _ -> not node.node_hidden

let bfs ~depth ~iter_succ f root =
  let module NodeSet = Graph.Node.Set in
  let queue : (node * int) Queue.t = Queue.create () in
  let marks = ref NodeSet.empty in
  Queue.add (root,0) queue;
  while not (Queue.is_empty queue) do
    let (n,d) = Queue.take queue in
    if not (NodeSet.mem n !marks) && d < depth then begin
      marks := NodeSet.add n !marks;
      f n;
      iter_succ (fun n' -> Queue.add (n',d+1) queue) n
    end
  done

let advance_computation context seq =
  let n = Context.get_max_dep_fetch_count context in
  match Seq.drop n seq () with
  | Seq.Nil -> Done
  | node -> Partial (fun () -> node)

let explore_backward ~depth context root =
  let iter_succ f n = Graph.iter_pred f (Context.get_graph context) n
  and explore_node n =
    if n.node_writes_computation <> Done && should_explore n root then begin
      let deps_builder =
        match n.node_writes_computation with
        | Done -> Seq.empty
        | Partial builder -> builder
        | NotDone -> build_node_writes context n
      in
      n.node_writes_computation <- advance_computation context deps_builder
    end
  in
  bfs ~depth ~iter_succ explore_node root

let explore_forward ~depth context root =
  let iter_succ f n = Graph.iter_succ f (Context.get_graph context) n
  and explore_node n =
    if n.node_reads_computation <> Done && should_explore n root then begin
      let deps_builder =
        match n.node_reads_computation with
        | Done -> Seq.empty
        | Partial builder -> builder
        | NotDone -> build_node_reads context n
      in
      n.node_reads_computation <- advance_computation context deps_builder
    end
  in
  bfs ~depth ~iter_succ explore_node root


(* --- Adding new roots --- *)

let complete context root =
  Context.add_root context root;
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
  Option.map (add_alarm context stmt) (Alarms.find annot)

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


(* --- Visibility handling --- *)

let remove_dependencies context node =
  (* Remove incomming edges *)
  Context.remove_node_deps context node;
  (* Reset the writes computation status *)
  node.node_writes_computation <- NotDone;
  Context.set_node_writes context node []

let remove_disconnected context =
  let roots = Context.get_roots context in
  let l = Graph.find_independant_nodes (Context.get_graph context) roots in
  List.iter (Context.remove_node context) l

let reduce_to_horizon context range new_root =
  (* Reduce to one root *)
  Context.set_unique_root context new_root ;
  (* List visible nodes *)
  let graph = Context.get_graph context
  and roots = Context.get_roots context
  and backward_bfs = Graph.bfs ~iter_succ:Graph.iter_pred ?limit:range.backward
  and forward_bfs = Graph.bfs ~iter_succ:Graph.iter_succ ?limit:range.forward in
  let bacward_nodes = backward_bfs graph roots
  and forward_nodes = forward_bfs graph roots in
  (* Table of visible nodes *)
  let module Table = Hashtbl.Make (Graph.Node) in
  let visible = Table.create 13 in
  let is_visible = Table.mem visible in
  List.iter (fun n -> Table.add visible n true) (bacward_nodes @ forward_nodes);
  (* Find nodes to hide / remove *)
  let update node =
    if not (is_visible node) then
      if List.exists is_visible (Graph.succ graph node) then
        remove_dependencies context node
      else
        Context.remove_node context node
  in
  Graph.iter_vertex update graph

let show _context node =
  node.node_hidden <- false

let hide context node =
  if not node.node_hidden then begin
    node.node_hidden <- true;
    Context.remove_root context node;
    remove_dependencies context node;
    remove_disconnected context
  end
