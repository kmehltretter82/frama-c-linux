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

let dkey = Options.dkey_translation

(* move all labels of [stmt] onto [new_stmt] *)
let move_labels env stmt new_stmt =
  let labels = stmt.labels in
  match labels with
  | [] -> ()
  | _ :: _ ->
    stmt.labels <- [];
    new_stmt.labels <- labels @ new_stmt.labels;
    (* update the gotos of the function jumping to one of the labels *)
    let o = object 
      inherit Visitor.frama_c_inplace
      method !vstmt_aux s = match s.skind with
      | Goto(s_ref, _) -> 
	(* [!s_ref] and [stmt] are not part of the same project, thus it
	   is safer to compare the ids than to use Stmt.equal *)
	if !s_ref.sid = stmt.sid then s_ref := new_stmt; 
	Cil.SkipChildren
      | _ -> Cil.DoChildren
      (* improve efficiency: skip childrens of vstmt which cannot
	 contain any stmt *)
      method !vinst _ = Cil.SkipChildren
      method !vexpr _ = Cil.SkipChildren
      method !vcode_annot _ = Cil.SkipChildren
      method !vlval _ = Cil.SkipChildren
    end in
    let vis = Env.get_visitor env in
    let f = Extlib.the vis#current_func in
    let mv_labels s =
      ignore (Visitor.visitFramacStmt o (Cil.get_stmt vis#behavior s))
    in
    List.iter mv_labels f.sallstmts

let rename_alloc_function stmt = 
  let is_alloc_name s = 
    s = "malloc" || s = "free" || s = "realloc" || s = "calloc"
  in
  match stmt.skind with 
  | Instr(Call(_, { enode = Lval(Var vi, _) }, _, _))
      when is_alloc_name vi.vname ->
    vi.vname <- "__" ^ vi.vname;
    Misc.mk_debug_mmodel_stmt stmt
  |_ -> 
    stmt

let allocate_function env kf =
  List.fold_left
    (fun env vi -> 
      if Pre_analysis.must_model_vi ~kf vi then
	let vi = Cil.get_varinfo (Env.get_behavior env) vi in
	Env.add_stmt env (Misc.mk_store_stmt vi)
      else
	env)
    env
    (Kernel_function.get_formals kf)

let deallocate_function env kf  = 
  List.fold_left
    (fun env vi -> 
      if Pre_analysis.must_model_vi ~kf vi then 
	let vi = Cil.get_varinfo (Env.get_behavior env) vi in
	Env.add_stmt env (Misc.mk_delete_stmt vi)
      else
	env)
    env
    (Kernel_function.get_formals kf)

(* ************************************************************************** *)
(* Visitor *)
(* ************************************************************************** *)

(* local references to the below visitor and to [do_visit] *)
let function_env = ref Env.dummy
let dft_funspec = Cil.empty_funspec ()
let funspec = ref dft_funspec

(* the main visitor performing e-acsl checking and C code generator *)
class e_acsl_visitor prj generate = object (self)

  inherit Visitor.generic_frama_c_visitor 
    (if generate then Cil.copy_visit prj else Cil.inplace_visit ())

  val mutable main_fct = None
  val mutable keep_initializer = None
  val global_vars: init option Varinfo.Hashtbl.t = Varinfo.Hashtbl.create 7
  (* keys belong to the original project while values belong to the new one *)

  method private reset_env () =
    function_env := Env.empty (self :> Visitor.frama_c_visitor)

  method !vfile _f =
    (* copy the options used during the visit in the new project: it is the
       right place to do this: it is still before visiting, but after
       that the visitor internals reset all of them :-(. *)
    let cur = Project.current () in
    let selection = 
      State_selection.of_list 
	[ Options.Gmp_only.self; Options.Check.self; Options.Full_mmodel.self;
	  Kernel.SignedOverflow.self; Kernel.UnsignedOverflow.self;
	  Kernel.SignedDowncast.self; Kernel.UnsignedDowncast.self;
	  Kernel.Machdep.self ] 
    in
    if generate then Project.copy ~selection ~src:cur prj;
    Cil.DoChildrenPost
      (fun f ->
	(* extend the main with forward initialization and put it at end *)
	if generate then begin
	  let must_init =
	    try
	      Varinfo.Hashtbl.iter
		(fun old_vi i -> match i with None | Some _ -> 
		  if Pre_analysis.must_model_vi old_vi then raise Exit)
		global_vars;
	      false
	    with Exit ->
	      true
	  in
	  if must_init then
	    let build_initializer () =
	      Options.feedback ~dkey ~level:2 "building global initializer.";
	      let return = 
		Cil.mkStmt ~valid_sid:true (Return(None, Location.unknown))
	      in
	      let env = Env.push !function_env in
	      let stmts, env = 
		Varinfo.Hashtbl.fold_sorted
		  (fun old_vi i (stmts, env) -> 
		    let new_vi = Cil.get_varinfo self#behavior old_vi in
		    let model blk =
		      if Pre_analysis.must_model_vi old_vi then
			Misc.mk_store_stmt new_vi :: blk
		      else
			stmts
		    in
		    match i with
		    | None -> model stmts, env
		    | Some (CompoundInit _) -> assert false
		    | Some (SingleInit e) -> 
		      let e, env = self#literal_string env e in
		      let stmt = 
			Cil.mkStmtOneInstr ~valid_sid:true
			  (Set(Cil.var new_vi, e, e.eloc))
		      in
		      model (stmt :: stmts), env)
		  global_vars
		  ([ return ], env)
	      in
	      let (b, env), stmts = match stmts with
		| [] -> assert false
		| stmt :: stmts ->
		  Env.pop_and_get env stmt ~global_clear:true Env.Before, stmts
	      in
	      function_env := env;
	      let stmts = Cil.mkStmt ~valid_sid:true (Block b) :: stmts in
	      let blk = Cil.mkBlock stmts in
	      let fname = "__e_acsl_memory_init" in
	      let vi = 
		Cil.makeGlobalVar ~logic:false ~generated:true 
		  fname
		  (TFun(Cil.voidType, Some [], false, []))
	      in
	      vi.vdefined <- true;
	      let spec = Cil.empty_funspec () in
	      let fundec =
		{ svar = vi;
		  sformals = [];
		  slocals = [];
		  smaxid = 0;
		  sbody = blk;
		  smaxstmtid = None;
		  sallstmts = [];
		  sspec = spec }
	      in
	      self#add_generated_variables_in_function fundec;
	      let fct = Definition(fundec, Location.unknown) in
	      let kf =
		{ fundec = fct; return_stmt = Some return; spec = spec } 
	      in
	      Globals.Functions.register kf;
	      Globals.Functions.replace_by_definition 
		spec fundec Location.unknown;
	      let cil_fct = GFun(fundec, Location.unknown) in
	      if Pre_analysis.use_model () then
		match main_fct with
		| Some main ->
		  let exp = Cil.evar ~loc:Location.unknown vi in
		  let stmt = 
		    Cil.mkStmtOneInstr ~valid_sid:true 
		      (Call(None, exp, [], Location.unknown))
		  in
		  vi.vreferenced <- true;
		  main.sbody.bstmts <- stmt :: main.sbody.bstmts;
		  let new_globals =
		    List.fold_right
		      (fun g acc -> match g with
		      | GFun({ svar = vi }, _)
			  when Varinfo.equal vi main.svar -> 
			acc
		      | _ -> g :: acc)
		      f.globals
		      [ cil_fct; GFun(main, Location.unknown) ]
		  in
		  f.globals <- new_globals
		| None -> 
		  Kernel.warning "@[no entry point specified:@ \
you must call function `%s' and `__e_acsl_memory_clean by yourself.@]" 
		    fname;
		  f.globals <- f.globals @ [ cil_fct ]
	    in
	    Project.on prj build_initializer ()
	end;
	(* reset copied states at the end to be observationally equivalent to a
	   standard visitor. *)
	if generate then Project.clear ~selection ~project:prj ();
	f)

  method !vglob_aux = function
  | GVarDecl(_, vi, _) | GVar(vi, _, _) | GFun({ svar = vi }, _) 
      when Misc.is_library_loc vi.vdecl ->
    if generate then
      Cil.JustCopyPost
	(fun l -> 
	  Misc.register_library_function (Cil.get_varinfo self#behavior vi);
	  l)
    else begin
      Misc.register_library_function vi; 
      Cil.SkipChildren
    end
  | GVarDecl(_, vi, _) | GVar(vi, _, _) | GFun({ svar = vi }, _) 
      when Cil.is_builtin vi ->
    if generate then Cil.JustCopy else Cil.SkipChildren
  | g when Misc.is_library_loc (Global.loc g) ->
    if generate then Cil.JustCopy else Cil.SkipChildren
  | g ->
    let do_it = function
      | GVar(vi, i, _) ->
	vi.vghost <- false;
	(* remove initializers on need *)
	if Pre_analysis.old_must_model_vi self#behavior vi then begin
	  try
	    let old_vi = Cil.get_original_varinfo self#behavior vi in
	    match Varinfo.Hashtbl.find global_vars old_vi with
	    | None -> ()
	    | Some _ -> i.init <- None
	  with Not_found ->
	    assert false
	end
      | GFun({ svar = vi } as fundec, _) ->
	vi.vghost <- false;
	(* remember that we have to remove the main later (see method
	   [vfile]) *)
	if vi.vorig_name = Kernel.MainFunction.get () then
	  main_fct <- Some fundec
      | GVarDecl(_, vi, _) -> 
	(* do not convert extern ghost variables, because they can't be linked,
	   see bts #1392 *)
	if vi.vstorage <> Extern then
	  vi.vghost <- false
      | _ -> 
	()
    in
    (match g with
    | GVar(vi, _, _) | GVarDecl(_, vi, _) -> 
      Varinfo.Hashtbl.replace global_vars vi None
    | _ -> ());
    if generate then Cil.DoChildrenPost(fun g -> List.iter do_it g; g)
    else Cil.DoChildren

  method !vinit vi _off _i = 
    if generate then
      if Pre_analysis.must_model_vi vi then begin
	keep_initializer <- Some true;
	Cil.DoChildrenPost
	  (fun i -> 
	    (match keep_initializer with
	    | Some false -> Varinfo.Hashtbl.replace global_vars vi (Some i)
	    | Some true | None -> ());
	    keep_initializer <- None; 
	    i)
      end else
	Cil.JustCopy
    else
      Cil.SkipChildren

  method !vvdec vi = 
    try
      let old_vi = Cil.get_original_varinfo self#behavior vi in
      let old_kf = Globals.Functions.get old_vi in
      funspec :=
	Cil.visitCilFunspec
	(self :> Cil.cilVisitor)
	(Annotations.funspec old_kf);
      Cil.DoChildren
    with Not_found ->
      Cil.DoChildren

  method private add_generated_variables_in_function f =
    assert generate;
    let vars = Env.get_generated_variables !function_env in
    self#reset_env ();
    f.slocals <- f.slocals @ List.map fst vars;
    let body = f.sbody in
    body.blocals <- 
      List.fold_left
      (fun acc (v, b) -> if b then v :: acc else acc) 
      body.blocals
      vars

  method !vfunc f =
    if generate then
      let kf = Extlib.the self#current_kf in
      Options.feedback ~dkey ~level:2 "entering in function %a." 
	Kernel_function.pretty kf;
      List.iter (fun vi -> vi.vghost <- false) f.slocals;
      Cil.DoChildrenPost 
	(fun f -> 
	  self#add_generated_variables_in_function f; 
	  Options.feedback ~dkey ~level:2 "function %a done."
	    Kernel_function.pretty kf;
	  f)
    else
      Cil.DoChildren

  method private is_return old_kf stmt = 
    let old_ret = 
      try Kernel_function.find_return old_kf
      with Kernel_function.No_Statement -> assert false
    in
    Stmt.equal stmt (Cil.get_stmt self#behavior old_ret)

  method private is_first_stmt old_kf stmt =
    try 
      Stmt.equal
	(Cil.get_original_stmt self#behavior stmt) 
	(Kernel_function.find_first_stmt old_kf)
    with Kernel_function.No_Statement -> 
      assert false

  method private is_main old_kf =
    try
      let main, _ = Globals.entry_point () in
      Kernel_function.equal old_kf main
    with Globals.No_such_entry_point _s ->
      (* [JS 2013/05/21] already a warning in pre-analysis *)
      (*      Options.warning ~once:true "%s@ \
	      @[The generated program may be incomplete.@]" 
	      s;*)
      false

  method private literal_string env e =
    assert generate;
    let env_ref = ref env in
    let o = object
      inherit Cil.genericCilVisitor (Cil.copy_visit (Project.current ()))
      method !vexpr e = match e.enode with
      | Const(CStr s) ->
	let loc = e.eloc in
	let _, exp, env = 
	  Env.new_var
	    ~loc
	    ~global:true
	    ~name:"literal_string"
	    env
	    None
	    Cil.charPtrType
	    (fun vi _ -> 
	      let str_size = Cil.new_exp loc (SizeOfStr s) in
	      [ Cil.mkStmtOneInstr 
		  ~valid_sid:true (Set(Cil.var vi, e, loc));
		Misc.mk_store_stmt ~str_size vi;
		Misc.mk_full_init_stmt ~addr:false vi;
		Misc.mk_literal_string vi ])
	in
	env_ref := env;
	Cil.ChangeTo exp
      | _ -> 
	Cil.DoChildren
    end in
    let e = Cil.visitCilExpr o e in
    e, !env_ref

  method !vstmt_aux stmt =
    Options.debug ~level:4 "proceeding stmt (sid %d) %a@." 
      stmt.sid Stmt.pretty stmt;
    let kf = Extlib.the self#current_kf in
    let is_main = self#is_main kf in
    let env = Env.push !function_env in
    let env = match stmt.skind with
      | Loop _ -> Env.push_loop env
      | _ -> env
    in
    let env = 
      if self#is_first_stmt kf stmt then
	(* JS: should be done in the new project? *)
	let env = if generate then allocate_function env kf else env in
	(* translate the precondition of the function *)
	if Pre_visit.is_generated_function (Extlib.the self#current_kf) then
	  Project.on prj (Translate.translate_pre_spec kf Kglobal env) !funspec
	else
	  env
      else
	env
    in
    let env, new_annots =
      Annotations.fold_code_annot
	(fun _ old_a (env, new_annots) -> 
	  let a =
            (* [VP] Don't use Visitor here, as it will fill the
	       queue in the middle of the computation... *)
	    Cil.visitCilCodeAnnotation (self :> Cil.cilVisitor) old_a
	  in
	  let env = 
	    Project.on
	      prj
	      (Translate.translate_pre_code_annotation kf stmt env)
	      a 
	  in
	  env, a :: new_annots)
	(Cil.get_original_stmt self#behavior stmt)
	(env, [])
    in
    function_env := env;
    let mk_block stmt =
      (* be careful: since this function is called in a post action, [env] has
	 been modified from the time where pre actions have been executed.
	 Use [function_env] to get it back. *)
      let env = !function_env in
      let env =
	if stmt.ghost && generate then begin
	  stmt.ghost <- false;
	  (* translate potential RTEs of ghost code *)
	  let rtes = Rte.stmt ~warn:false kf stmt in
	  Translate.translate_rte_annots Printer.pp_stmt stmt kf env rtes
	end else
	  env
      in
      let mk_post_env env =
	(* [fold_right] to preserve order of generation of pre_conditions *) 
	Project.on
	  prj
	  (List.fold_right
	     (fun a env -> 
	       Translate.translate_post_code_annotation kf stmt env a)
	     new_annots)
	  env
      in
      (* handle loop invariants *)
      let new_stmt, env, must_mv = Loops.preserve_invariant prj env kf stmt in
      let new_stmt, env = 
	if self#is_return kf stmt then 
	  (* must generate the post_block before including [stmt] (the 'return')
	     since no code is executed after it. However, since this statement
	     is pure (Cil invariant), that is semantically correct. *)
	  let env = mk_post_env env in
	  (* also handle the postcondition of the function and clear the env *)
	  let env = 
	    if Pre_visit.is_generated_function (Extlib.the self#current_kf) then
	      Project.on
		prj
		(Translate.translate_post_spec kf Kglobal env) 
		!funspec 
	    else
	      env
	  in
	  (* de-allocating memory previously allocating by the kf *)
	  (* JS: should be done in the new project? *)
	  if generate then
	    let env = deallocate_function env kf in
	    let b, env = 
	      Env.pop_and_get env new_stmt ~global_clear:true Env.After 
	    in
	    if is_main && Pre_analysis.use_model () then begin
	      let stmts = b.bstmts in
	      let l = List.rev stmts in
	      match l with
	      | [] -> assert false (* at least the 'return' stmt *)
	      | ret :: l ->
		let loc = Stmt.loc stmt in
		let delete_stmts =
		  Globals.Vars.fold_in_file_order
		    (fun vi _ acc -> 
		      if Pre_analysis.must_model_vi vi then 
			let vi = Cil.get_varinfo self#behavior vi in
			Misc.mk_delete_stmt vi :: acc
		      else
			acc)
		    [ Misc.mk_call ~loc "__e_acsl_memory_clean" []; ret ]
		in
		b.bstmts <- List.rev l @ delete_stmts
	    end;
	    let new_stmt = Misc.mk_block prj stmt b in
	    (* move the labels of the return to the new block in order to
	       evaluate the postcondition when jumping to them. *)
	    move_labels env stmt new_stmt;
	    new_stmt, env
	  else
	    stmt, env
	else (* i.e. not (is_return stmt) *)
	  if generate then
	    let stmt = rename_alloc_function new_stmt in
	    (* must generate [pre_block] which includes [stmt] before generating
	       [post_block] *)
	    let pre_block, env = 
	      Env.pop_and_get env stmt ~global_clear:false Env.After
	    in
	    let env = mk_post_env (Env.push env) in
	    let post_block, env = 
	      Env.pop_and_get 
		env
		(Misc.mk_block prj stmt pre_block) 
		~global_clear:false 
		Env.Before 
	    in
	    (* TODO: must clear the local block anytime (?) *)
	    Misc.mk_block prj stmt post_block, env
	  else
	    stmt, env
      in
      if must_mv then Loops.mv_invariants env ~old:new_stmt stmt;
      function_env := env;
      Options.debug ~level:4
	"@[new stmt (from sid %d):@ %a@]" stmt.sid Printer.pp_stmt new_stmt;
      if generate then new_stmt else stmt
    in
    Cil.ChangeDoChildrenPost(stmt, mk_block)

  method private add_initializer loc checked_lv assigned_lv =
    assert generate;
    let kf = Extlib.the self#current_kf in
    let stmt = Extlib.the self#current_stmt in
    let may_safely_ignore = function
      | Var vi, NoOffset -> vi.vglob || vi.vformal
      | _ -> false
    in
(*    Options.feedback "%a? %a (%b && %b)" 
      Printer.pp_lval assigned_lv 
      Printer.pp_lval checked_lv
      (not (may_safely_ignore assigned_lv))
      (Pre_analysis.must_model_lval ~kf ~stmt checked_lv);*)
    if not (may_safely_ignore assigned_lv) && 
      Pre_analysis.must_model_lval ~kf ~stmt checked_lv 
    then begin
      let stmt = 
	Misc.mk_debug_mmodel_stmt (Misc.mk_initialize loc assigned_lv) 
      in
      function_env := Env.add_stmt !function_env stmt
    end

  method !vinst = function
  | Set(old_lv, _, _) ->
    if generate then
      Cil.DoChildrenPost 
	(function 
	| [ Set(new_lv, _, loc) ] as l -> 
	  self#add_initializer loc old_lv new_lv; 
	  l
	| _ -> assert false)
    else
      Cil.DoChildren
  | Call(Some old_ret, _, _, _) ->
    if not generate || Misc.is_generated_kf (Extlib.the self#current_kf) then
      Cil.DoChildren
    else
      Cil.DoChildrenPost 
	(function 
	| [ Call(Some new_ret, _, _, loc) ] as l -> 
	  self#add_initializer loc old_ret new_ret;
	  l
	| _ -> assert false)
  | _ ->
    Cil.DoChildren

  method !vblock blk =
    let handle_memory new_blk = 
      match new_blk.blocals with
      | [] -> new_blk
      | _ :: _ ->
	let kf = Extlib.the self#current_kf in
	let add_locals stmts =
	  List.fold_left
	    (fun acc vi ->
	      if Pre_analysis.old_must_model_vi self#behavior ~kf vi then
		Misc.mk_delete_stmt vi :: acc
	      else
		acc)
	    stmts
	    new_blk.blocals
	in
	let rec insert_in_innermost_last_block blk = function
	  | { skind = Return _ } as ret :: ((potential_clean :: tl) as l) ->
	    (* keep the return (enclosed in a generated block) at the end;
	       preceded by clean if any *)
	    let init, tl = 
	      if self#is_main kf && Pre_analysis.use_model () then
		[ potential_clean; ret ], tl
	      else
		[ ret ], l
	    in
	    blk.bstmts <-
	      List.fold_left (fun acc v -> v :: acc) (add_locals init) tl
	  | { skind = Block b } :: _ -> 
	    insert_in_innermost_last_block b (List.rev b.bstmts)
	  | l -> blk.bstmts <- 
	    List.fold_left (fun acc v -> v :: acc) (add_locals []) l
	in
	insert_in_innermost_last_block new_blk (List.rev new_blk.bstmts);
	new_blk.bstmts <-
	  List.fold_left
	  (fun acc vi -> 
	    if Pre_analysis.must_model_vi vi
	    then 
	      let vi = Cil.get_varinfo self#behavior vi in
	      Misc.mk_store_stmt vi :: acc
	    else acc)
	  new_blk.bstmts
	  blk.blocals;
	new_blk
    in
    if generate then Cil.DoChildrenPost handle_memory else Cil.DoChildren

  method !vexpr exp = 
    if generate then
      match keep_initializer with
      | Some false -> Cil.JustCopy
      | Some true ->       
	let keep = match exp.enode with Const(CStr _) -> false | _ -> true  in
	keep_initializer <- Some keep;
	if keep then Cil.DoChildren else Cil.JustCopy
      | None -> 
	Cil.DoChildrenPost
	  (fun e -> 
	    let e, env = self#literal_string !function_env e in
	    function_env := env;
	    e)
    else
      Cil.SkipChildren

  initializer 
    Misc.reset ();
    self#reset_env ();
    Translate.set_original_project (Project.current ())

end

let do_visit ?(prj=Project.current ()) generate =
  Options.feedback ~level:2 "%s annotations in %a." 
    (if generate then "translating" else "checking")
    Project.pretty prj;
  let vis =
    Extlib.try_finally ~finally:Typing.clear (new e_acsl_visitor prj) generate
  in
  (* explicit type annotation in order to check that no new method is
     introduced by error *)
  (vis : Visitor.frama_c_visitor)

(*
Local Variables:
compile-command: "make"
End:
*)
