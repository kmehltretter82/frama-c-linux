(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2013                                               *)
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
open Cil_datatype

let init_mpz () =
  Options.feedback ~level:2 "initializing GMP type.";
  let set_mpzt = object
    inherit Cil.nopCilVisitor
    method vglob = function
    | GType({ torig_name = s } as info, _) when s = "mpz_t" ->
      Mpz.set_t info;
      Cil.SkipChildren
    | _ -> 
      Cil.SkipChildren
  end in
  Cil.visitCilFileSameGlobals set_mpzt (Ast.get ())

(* ********************************************************************** *)
(* Backward dataflow analysis to compute a sound over-approximation of what
   left-values must be tracked by the memory model library *)
(* ********************************************************************** *)

let dkey = Options.dkey_analysis

let get_rte_by_stmt =
  Misc.rte2
    "stmt_annotations"
    (Datatype.func2 Kernel_function.ty Stmt.ty 
       (let module L = Datatype.List(Code_annotation) in L.ty))

module Env: sig
  val default_varinfos: Varinfo.Set.t option -> Varinfo.Set.t
  val apply: (kernel_function -> 'a) -> kernel_function -> 'a
  val clear: unit -> unit
  val add: kernel_function -> Varinfo.Set.t option Stmt.Hashtbl.t -> unit
  val find: kernel_function -> Varinfo.Set.t option Stmt.Hashtbl.t 
  module StartData: Dataflow.StmtStartData with type data = Varinfo.Set.t option
  val is_consolidated: unit -> bool
  val consolidate: Varinfo.Set.t -> unit
  val consolidated_mem: varinfo -> bool
end = struct

  let current_kf = ref (Kernel_function.dummy ())
  let default_varinfos = function None -> Varinfo.Set.empty | Some s -> s 

  let apply f kf =
    let old = !current_kf in
    current_kf := kf;
    let res = f kf in
    current_kf := old;
    res

  let tbl = Kernel_function.Hashtbl.create 7
  let add = Kernel_function.Hashtbl.add tbl
  let find = Kernel_function.Hashtbl.find tbl

  module StartData = struct
    type data = Varinfo.Set.t option
    let apply f = 
      try
	let h =  Kernel_function.Hashtbl.find tbl !current_kf in
	f h
      with Not_found -> 
	assert false
    let clear () = apply Stmt.Hashtbl.clear
    let mem k = apply Stmt.Hashtbl.mem k
    let find k = apply Stmt.Hashtbl.find k
    let replace k v = apply Stmt.Hashtbl.replace k v
    let add k v = apply Stmt.Hashtbl.add k v
    let iter f = apply (Stmt.Hashtbl.iter f)
    let length () = apply Stmt.Hashtbl.length
  end

  let consolidated_set = ref Varinfo.Set.empty
  let is_consolidated_ref = ref false

  let consolidate set = 
    let set = Varinfo.Set.fold Varinfo.Set.add set !consolidated_set in
    consolidated_set := set

  let consolidated_mem v = 
    is_consolidated_ref := true;
    Varinfo.Set.mem v !consolidated_set

  let is_consolidated () = !is_consolidated_ref

  let clear () = 
    Kernel_function.Hashtbl.clear tbl;
    consolidated_set := Varinfo.Set.empty;
    is_consolidated_ref := false

end

let reset () = 
  Options.feedback ~dkey ~level:2 "clearing environment.";
  Env.clear ()

module rec Transfer
  : Dataflow.BackwardsTransfer with type t = Varinfo.Set.t option
  = struct

  let name = "E_ACSL.Pre_analysis"

  let debug = ref false

  type t = Varinfo.Set.t option

  module StmtStartData = Env.StartData

  let pretty fmt state = match state with
    | None -> Format.fprintf fmt "None"
    | Some s -> Format.fprintf fmt "%a" Varinfo.Set.pretty s

  (** The data at function exit. Used for statements with no successors.
      This is usually bottom, since we'll also use doStmt on Return
      statements. *)
  let funcExitData = None

  (** When the analysis reaches the start of a block, combine the old data with
      the one we have just computed. Return None if the combination is the same
      as the old data, otherwise return the combination. In the latter case, the
      predecessors of the statement are put on the working list. *)
  let combineStmtStartData stmt ~old state = match stmt.skind, old, state with
    | _, _, None -> assert false
    | _, None, Some _ -> Some state (* [old] already included in [state] *)
    | Return _, Some old, Some new_ -> Some (Some (Varinfo.Set.union old new_))
    | _, Some old, Some new_ -> 
      if Varinfo.Set.equal old new_ then
	None
      else
	Some (Some (Varinfo.Set.union old new_))

  (** Take the data from two successors and combine it *)
  let combineSuccessors s1 s2 = 
    Some (Varinfo.Set.union (Env.default_varinfos s1) (Env.default_varinfos s2))

  let is_ptr_or_array ty = Cil.isPtrType ty || Cil.isArrayType ty

  let is_ptr_or_array_exp e =
    let ty = Cil.typeOf e in
    is_ptr_or_array ty

  let rec register_term_lval kf varinfos (thost, _) = match thost with
    | TVar { lv_origin = None } -> varinfos
    | TVar { lv_origin = Some vi } -> Varinfo.Set.add vi varinfos
    | TResult _ -> Varinfo.Set.add (Misc.result_vi kf) varinfos
    | TMem t -> register_term kf varinfos t

  and register_term kf varinfos term = match term.term_node with
    | TLval tlv | TAddrOf tlv | TStartOf tlv -> 
      register_term_lval kf varinfos tlv
    | TCastE(_, t) | Tat(t, _) | Tlet(_, t) ->
      register_term kf varinfos t
    | Tif(_, t1, t2) ->
      let varinfos = register_term kf varinfos t1 in
      register_term kf varinfos t2
    | TBinOp((PlusPI | IndexPI | MinusPI), t1, t2) ->
      (match t1.term_type with
      | Ctype ty when is_ptr_or_array ty -> register_term kf varinfos t1
      | _ -> 
	match t2.term_type with
	| Ctype ty when is_ptr_or_array ty -> register_term kf varinfos t2
	| _ -> assert false)
    | TConst _ | TSizeOf _ | TSizeOfE _ | TSizeOfStr _ | TAlignOf _
    | TAlignOfE _ | Tnull | Ttype _ | TUnOp _ | TBinOp _ ->
      varinfos
    | Tlambda(_, _) -> Error.not_yet "lambda function"
    | Tapp(_, _, _) -> Error.not_yet "function application"
    | TDataCons _ -> Error.not_yet "data constructor"
    | Tbase_addr _ -> Error.not_yet "\\base_addr"
    | Toffset _ -> Error.not_yet "\\offset"
    | Tblock_length _ -> Error.not_yet "\\block_length"
    | TLogic_coerce(_, t) -> register_term kf varinfos t
    | TCoerce _ -> Error.not_yet "coerce"
    | TCoerceE _ -> Error.not_yet "coerce expression"
    | TUpdate _ -> Error.not_yet "functional update"
    | Ttypeof _ -> Error.not_yet "typeof"
    | Tempty_set -> Error.not_yet "empty set"
    | Tunion _ -> Error.not_yet "set union"
    | Tinter _ -> Error.not_yet "set intersection"
    | Tcomprehension _ -> Error.not_yet "set comprehension"
    | Trange _ -> Error.not_yet "\\range"

  let register_object kf state_ref = object
    inherit Visitor.frama_c_inplace
    method vpredicate = function
    | Pvalid(_, t) | Pvalid_read(_, t) | Pinitialized(_, t) ->
      (*	Options.feedback "REGISTER %a" Cil.d_term t;*)
      state_ref := register_term kf !state_ref t;
      Cil.DoChildren
    | Pallocable _ -> Error.not_yet "\\allocable"
    | Pfreeable _ -> Error.not_yet "\\freeable"
    | Pfresh _ -> Error.not_yet "\\fresh"
    | Pseparated _ -> Error.not_yet "\\separated"
    | Ptrue | Pfalse | Papp _ | Prel _
    | Pand _ | Por _ | Pxor _ | Pimplies _ | Piff _ | Pnot _ | Pif _ 
    | Plet _ | Pforall _ | Pexists _ | Pat _ | Psubtype _ ->
      Cil.DoChildren
    method vterm term = match term.term_node with
    | Tbase_addr(_, t) | Toffset(_, t) | Tblock_length(_, t) ->
      state_ref := register_term kf !state_ref t;
      Cil.DoChildren
    | TConst _ | TSizeOf _ | TSizeOfStr _ | TAlignOf _  | Tnull | Ttype _ 
    | Tempty_set -> 
      (* no left-value inside inside: skip for efficiency *)
      Cil.SkipChildren
    | TUnOp _ | TBinOp _ | Ttypeof _ | TSizeOfE _
    | TLval _ | TAlignOfE _ | TCastE _ | TAddrOf _
    | TStartOf _ | Tapp _ | Tlambda _ | TDataCons _ | Tif _ | Tat _
    | TCoerce _ | TCoerceE _ | TUpdate _ | Tunion _ | Tinter _
    | Tcomprehension _ | Trange _ | Tlet _ | TLogic_coerce _ -> 
      (* potential sub-term inside *)
      Cil.DoChildren
    method vlogic_label _ = Cil.SkipChildren
    method vterm_lhost = function
    | TMem t ->
      (* potential RTE *)
      state_ref := register_term kf !state_ref t;
      Cil.DoChildren
    | TVar _ | TResult _ -> 
      Cil.SkipChildren
  end

  let register_predicate kf pred state = 
    let state_ref = ref state in
    Error.handle
      (fun () ->
	ignore
	  (Visitor.visitFramacIdPredicate (register_object kf state_ref) pred))
      ();
    !state_ref

  let register_code_annot kf a state = 
    let state_ref = ref state in
    Error.handle
      (fun () ->
	ignore 
	  (Visitor.visitFramacCodeAnnotation (register_object kf state_ref) a))
      ();
    !state_ref

  (** The (backwards) transfer function for a branch. The [(Cil.CurrentLoc.get
      ())] is set before calling this. If it returns None, then we have some
      default handling. Otherwise, the returned data is the data before the
      branch (not considering the exception handlers) *)
  let doStmt stmt =
    let _, kf = Kernel_function.find_from_sid stmt.sid in
    let is_first =
      try Stmt.equal stmt (Kernel_function.find_first_stmt kf) 
      with Kernel_function.No_Statement -> assert false
    in
    let is_last =
      try Stmt.equal stmt (Kernel_function.find_return kf) 
      with Kernel_function.No_Statement -> assert false
    in
    Dataflow.Post 
      (fun state ->
	let state = Env.default_varinfos state in
	let state = 
	  if (is_first || is_last) && Misc.is_generated_kf kf then 
	    Annotations.fold_behaviors
	      (fun _ bhv s -> 
		let handle_annot test f s =
		  if test then 
		    f (fun _ p s -> register_predicate kf p s) kf bhv.b_name s
		  else
		    s
		in
		let s = handle_annot is_first Annotations.fold_requires s in
		let s = handle_annot is_first Annotations.fold_assumes s in
		handle_annot 
		  is_last 
		  (fun f -> Annotations.fold_ensures (fun e (_, p) -> f e p)) s)
	      kf
	      state
	  else
	    state
	in
	let state = 
	  Annotations.fold_code_annot
	    (fun _ -> register_code_annot kf) stmt state
	in
	let state =
	  if stmt.ghost then
	    let rtes = get_rte_by_stmt kf stmt in
	    List.fold_left
	      (fun state a -> register_code_annot kf a state) state rtes
	  else 
	    state
	in
	Some state)

  let rec base_addr_node = function
    | Lval lv | AddrOf lv | StartOf lv -> 
      (match lv with
      | Var vi, _ -> Some vi
      | Mem e, _ -> base_addr e)
    | BinOp((PlusPI | IndexPI | MinusPI), e1, e2, _) -> 
      if is_ptr_or_array_exp e1 then base_addr e1
      else begin
	assert (is_ptr_or_array_exp e2);
	base_addr e2
      end
    | Info(e, _) | CastE(_, e) -> base_addr e
    | BinOp((MinusPP | PlusA | MinusA | Mult | Div | Mod |Shiftlt | Shiftrt 
		| Lt | Gt | Le | Ge | Eq | Ne | BAnd | BXor | BOr | LAnd | LOr),
	    _, _, _)
    | UnOp _ | Const _ | SizeOf _ | SizeOfE _ | SizeOfStr _ | AlignOf _ 
    | AlignOfE _ -> 
      None

  and base_addr e = base_addr_node e.enode

  (** The (backwards) transfer function for an instruction. The
      [(Cil.CurrentLoc.get ())] is set before calling this. If it returns
      None, then we have some default handling. Otherwise, the returned data is
      the data before the branch (not considering the exception handlers) *)
  let doInstr _stmt instr state = 
    let state = Env.default_varinfos state in
    let extend_to_expr state lhost e =
      let add_vi state vi =
	if is_ptr_or_array_exp e && Varinfo.Set.mem vi state then 
	  match base_addr e with
	  | None -> state
	  | Some vi_e -> Varinfo.Set.add vi_e state
	else 
	  state
      in
      match lhost with
      | Var vi -> add_vi state vi
      | Mem e -> 
	match base_addr e with
	| None -> Kernel.fatal "no base address for %a" Printer.pp_exp e
	| Some vi -> add_vi state vi
    in
    match instr with
    | Set((lhost, _), e, _) -> 
      Dataflow.Done (Some (extend_to_expr state lhost e))
    | Call(result, f_exp, l, _) -> 
      (match f_exp.enode with
      | Lval(Var vi, NoOffset) ->
	let kf = Globals.Functions.get vi in
	let params = Globals.Functions.get_params kf in
	let state =
	  if Kernel_function.is_definition kf then
	    try
	      (* compute the initial state of the called function *)
	      let init =
		List.fold_left2
		  (fun acc p a -> match base_addr a with
		    | None -> acc
		    | Some vi -> 
		      if Varinfo.Set.mem vi state then Varinfo.Set.add p acc
		      else acc)
		  state
		  params
		  l
	      in
	      let init = match result with
		| None -> init
		| Some lv ->
		  match base_addr_node (Lval lv) with
		  | None -> init
		  | Some vi ->
		    if Varinfo.Set.mem vi state 
		    then Varinfo.Set.add (Misc.result_vi kf) init
		    else init
	      in
	      let state = Compute.get ~init kf in
	      (* compute the resulting state by keeping arguments whenever the
		 corresponding formals must be kept *)
	      List.fold_left2
		(fun acc p a -> match base_addr a with
		| None -> acc
		| Some vi ->
		  if  Varinfo.Set.mem p state then Varinfo.Set.add vi acc
		  else acc)
		state
		params
		l
	    with Invalid_argument _ -> 
	      Options.warning
		"ignoring effect of variadic function %a" 
		Kernel_function.pretty
		kf;
	      state
	  else
	    state
	in
	let state = match result with
	  | None -> state
	  | Some (lhost, _) ->
	    (* result of this call must be kept; so keep each argument *)
	    List.fold_left (fun acc e -> extend_to_expr acc lhost e) state l
	in
	Dataflow.Done (Some state)
      | _ ->
	Options.warning "function pointers may introduce too limited \
instrumentation.";
	(* imprecise function call: keep each argument *)
	Dataflow.Done 
	  (Some
	     (List.fold_left
		(fun acc e -> match base_addr e with
		| None -> acc
		| Some vi -> Varinfo.Set.add vi acc)
		state 
		l)))
    | Asm _ -> Error.not_yet "asm"
    | Skip _ | Code_annot _ -> Dataflow.Default

  (** Whether to put this statement in the worklist. This is called when a
      block would normally be put in the worklist. *)
  let filterStmt _predecessor _block = true

  (** Must return [true] if there is a path in the control-flow graph of the
      function from the first statement to the second. Used to choose a "good"
      node in the worklist. Suggested use is [let stmt_can_reach =
      Stmts_graph.stmt_can_reach kf], where [kf] is the kernel_function
      being analyzed; [let stmt_can_reach _ _ = true] is also correct,
      albeit less efficient *)
  let stmt_can_reach stmt = 
    let _, kf = Kernel_function.find_from_sid stmt.sid in
    Stmts_graph.stmt_can_reach kf stmt

end

and Compute: sig 
  val get: ?init:Varinfo.Set.t -> kernel_function -> Varinfo.Set.t 
end = struct

  module D = Dataflow.Backwards(Transfer)

  let compute init_set kf = 
    Options.feedback ~dkey ~level:2 "entering in function %a." 
      Kernel_function.pretty kf;
    assert (not (Misc.is_library_loc (Kernel_function.get_location kf)));
    let tbl = Stmt.Hashtbl.create 17 in
(*    Options.feedback "ANALYSING %a" Kernel_function.pretty kf;*)
    Env.add kf tbl;
    (try
      let fundec = Kernel_function.get_definition kf in
      let stmts, returns = Dataflow.find_stmts fundec in
      List.iter (fun s -> Stmt.Hashtbl.add tbl s None) stmts;
      Extlib.may
	(fun set -> 
	  List.iter (fun s -> Stmt.Hashtbl.replace tbl s (Some set)) returns)
	init_set;
      D.compute returns
    with Kernel_function.No_Definition | Kernel_function.No_Statement -> 
      ());
    Options.feedback ~dkey ~level:2 "function %a done." 
      Kernel_function.pretty kf;
    tbl

  let get ?init kf =
    if Misc.is_library_loc (Kernel_function.get_location kf) then
      Varinfo.Set.empty
    else
      try
	let stmt = Kernel_function.find_first_stmt kf in
	(*      Options.feedback "GETTING %a" Kernel_function.pretty kf;*)
	let tbl = 
	  try Env.find kf
	  with Not_found -> Env.apply (compute init) kf 
	in
	try
	  let set = Stmt.Hashtbl.find tbl stmt in
	  Env.default_varinfos set
	with Not_found ->
	  Options.fatal "stmt never analyzed: %a" Printer.pp_stmt stmt
      with Kernel_function.No_Statement -> 
	Varinfo.Set.empty

end

let consolidated_must_model_vi vi =
  if Env.is_consolidated () then
    Env.consolidated_mem vi
  else begin
    Options.feedback ~level:2 "performing pre-analysis for minimal memory \
instrumentation.";
    (try
       let main, _ = Globals.entry_point () in
       let set = Compute.get main in
       Env.consolidate set
     with Globals.No_such_entry_point s ->
       Options.warning ~once:true "%s@ \
@[The generated program may miss memory instrumentation.@]"
	 s);
    Options.feedback ~level:2 "pre-analysis done.";
    Env.consolidated_mem vi
  end

let must_model_vi ?kf ?stmt vi =
  let kf = match kf, stmt with
    | None, None | Some _, _ -> kf
    | None, Some stmt -> Some (Kernel_function.find_englobing_kf stmt)
  in
  match stmt, kf with
  | None, _ -> consolidated_must_model_vi vi
  | Some _, None ->
    assert false
  | Some stmt, Some kf  ->
    if not (Env.is_consolidated ()) then 
      ignore (consolidated_must_model_vi vi);
    try
      let tbl = Env.find kf in
      try
	let set = Stmt.Hashtbl.find tbl stmt in
	Varinfo.Set.mem vi (Env.default_varinfos set)
      with Not_found -> 
	(* new statement *)
	consolidated_must_model_vi vi
    with Not_found -> 
      (* [kf] is dead code *)
      false

let rec must_model_lval ?kf ?stmt = function
  | Var vi, _ -> must_model_vi ?kf ?stmt vi
  | Mem e, _ -> must_model_exp ?kf ?stmt e

and must_model_exp ?kf ?stmt e = match e.enode with
  | Lval lv | AddrOf lv | StartOf lv -> must_model_lval ?kf ?stmt lv
  | BinOp((PlusPI | IndexPI | MinusPI), e1, _, _) -> must_model_exp ?kf ?stmt e1
  | BinOp(MinusPP, e1, e2, _) -> 
    must_model_exp ?kf ?stmt e1 || must_model_exp ?kf ?stmt e2
  | Info(e, _) | CastE(_, e) -> must_model_exp ?kf ?stmt e
  | BinOp((PlusA | MinusA | Mult | Div | Mod |Shiftlt | Shiftrt 
	      | Lt | Gt | Le | Ge | Eq | Ne | BAnd | BXor | BOr | LAnd | LOr),
	  _, _, _)
  | UnOp _ | Const _ | SizeOf _ | SizeOfE _ | SizeOfStr _ | AlignOf _ 
  | AlignOfE _ -> assert false

let must_model_vi ?kf ?stmt vi =
  Options.Full_mmodel.get ()
  || Error.generic_handle (must_model_vi ?kf ?stmt) false vi

let must_model_lval ?kf ?stmt lv = 
  Options.Full_mmodel.get ()
  || Error.generic_handle (must_model_lval ?kf ?stmt) false lv

let old_must_model_vi bhv ?kf ?stmt vi =
  Options.Full_mmodel.get ()
  || must_model_vi ?kf ?stmt (Cil.get_original_varinfo bhv vi)

(*
Local Variables:
compile-command: "make"
End:
*)
