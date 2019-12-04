(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2018                                               *)
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

module E_acsl_label = Label (* [Label] is hidden when opening [Cil_datatype *)
open Cil_types
open Cil_datatype

let dkey = Options.dkey_translation

(* ************************************************************************** *)
(* Code *)
(* ************************************************************************** *)

let replace_literal_string_in_exp env kf_opt (* None for globals *) e =
  (* do not touch global initializers because they accept only constants;
     replace literal strings elsewhere *)
  match kf_opt with
  | None -> e, env
  | Some kf -> Literal_observer.exp_in_depth env kf e

let rec inject_in_init env kf_opt vi off = function
  | SingleInit e as init ->
    if vi.vglob then Global_observer.add_initializer vi off init;
    let e, env = replace_literal_string_in_exp env kf_opt e in
    SingleInit e, env
  | CompoundInit(typ, l) ->
    (* inject in all single initializers that can be built from the compound
       version *)
    let l, env =
      List.fold_left
        (fun (l, env) (off', i) ->
           let new_off = Cil.addOffset off' off in
           let i, env = inject_in_init env kf_opt vi new_off i in
           (off', i) :: l, env)
        ([], env)
        l
    in
    CompoundInit(typ, List.rev l), env

let inject_in_local_init loc env kf vi = function
  | ConsInit (fvi, _sz :: _, _) as init
    when Functions.Libc.is_vla_alloc_name fvi.vname ->
    (* handle variable-length array allocation via [__fc_vla_alloc].  Here each
       instance of [__fc_vla_alloc] is rewritten to [alloca] (that is used to
       implement VLA) and further a custom call to [store_block] tracking VLA
       allocation is issued. *)
    (* KV: do not add handling [alloca] allocation here (or anywhere else for
       that matter). Handling of [alloca] should be implemented in Frama-C
       (eventually). This is such that each call to [alloca] becomes
       [__fc_vla_alloc]. It is already handled using the code below. *)
    fvi.vname <- Functions.Libc.actual_alloca;
    (* Since we need to pass [vi] by value, cannot use [Misc.mk_store_stmt]
       here. Do it manually. *)
    let store = Constructor.mk_store_stmt vi in
    let env = Env.add_stmt ~post:true env kf store in
    init, env

  | ConsInit (fvi, args, kind)
    when Options.Validate_format_strings.get ()
      && Functions.Libc.is_printf_name fvi.vname
    ->
    (* rewrite format functions (e.g., [printf]). *)
    let name = Functions.RTL.get_rtl_replacement_name fvi.vname in
    let new_vi = Misc.get_lib_fun_vi name in
    let fmt = Functions.Libc.get_printf_argument_str ~loc fvi.vname args in
    ConsInit(new_vi, fmt :: args, kind), env

  | ConsInit (fvi, _, _) as init
    when Options.Replace_libc_functions.get ()
      && Functions.RTL.has_rtl_replacement fvi.vname
    ->
    (* rewrite names of functions for which we have alternative definitions in
       the RTL. *)
    fvi.vname <- Functions.RTL.get_rtl_replacement_name fvi.vname;
    init, env

  | AssignInit init ->
    let init, env = inject_in_init env (Some kf) vi NoOffset init in
    AssignInit init, env

  | ConsInit(vi, l, ck) ->
    let l, env =
      List.fold_right
        (fun e (l, env) ->
           let e, env = replace_literal_string_in_exp env (Some kf) e in
           e :: l, env)
        l
        ([], env)
    in
    ConsInit(vi, l, ck), env

(* rewrite names of functions for which we have alternative definitions in the
   RTL. *)
let rename_caller loc args exp = match exp.enode with
  | Lval(Var vi, _)
    when Options.Replace_libc_functions.get ()
      && Functions.RTL.has_rtl_replacement vi.vname
    ->
    vi.vname <- Functions.RTL.get_rtl_replacement_name vi.vname;
    exp, args

  | Lval(Var vi , _) when Functions.Libc.is_vla_free_name vi.vname ->
    (* handle variable-length array allocation via [__fc_vla_free]. Rewrite its
       name to [delete_block]. The rest is in place. *)
    vi.vname <- Functions.RTL.mk_api_name "delete_block";
    exp, args

  | Lval(Var vi, _)
    when Options.Validate_format_strings.get ()
      && Functions.Libc.is_printf_name vi.vname
    ->
    (* rewrite names of format functions (such as printf). This case differs
       from the above because argument list of format functions is extended with
       an argument describing actual variadic arguments *)
    (* replacement name, e.g., [printf] -> [__e_acsl_builtin_printf] *)
    let name = Functions.RTL.get_rtl_replacement_name vi.vname in
    (* variadic arguments descriptor *)
    let fmt = Functions.Libc.get_printf_argument_str ~loc vi.vname args in
    (* get the name of the library function we need. Cannot just rewrite the
       name as AST check will then fail *)
    let vi = Misc.get_lib_fun_vi name in
    Cil.evar vi, fmt :: args

  | _ ->
    exp, args

(* TODO: should be better documented *)
let add_initializer loc ?vi lv ?(post=false) stmt env kf =
  if Functions.instrument kf then
    let may_safely_ignore = function
      | Var vi, NoOffset -> vi.vglob || vi.vformal
      | _ -> false
    in
    let must_model = Mmodel_analysis.must_model_lval ~stmt ~kf lv in
    if not (may_safely_ignore lv) && must_model then
      let before = Cil.mkStmt ~valid_sid:true stmt.skind in
      let new_stmt =
        (* bitfields are not yet supported ==> no initializer.
           a [not_yet] will be raised in [Translate]. *)
        if Cil.isBitfield lv then Cil.mkEmptyStmt ()
        else Constructor.mk_initialize ~loc lv
      in
      let env = Env.add_stmt ~post ~before env kf new_stmt in
      let env = match vi with
        | None -> env
        | Some vi ->
          let new_stmt = Constructor.mk_store_stmt vi in
          Env.add_stmt ~post ~before env kf new_stmt
      in
      env
    else
      env
  else
    env

let inject_in_instr env kf stmt instr =
  (* [TODO ARCHI] recursive calls at the right places *)
  match instr with
  | Set(lv, e, loc) ->
    let e, env = replace_literal_string_in_exp env (Some kf) e in
    let env = add_initializer loc lv stmt env kf in
    Set(lv, e, loc), env

  | Call(result, caller, args, loc) ->
    let args, env =
      List.fold_right
        (fun a (args, env) ->
           let a, env = replace_literal_string_in_exp env (Some kf) a in
           a :: args, env)
        args
        ([], env)
    in
    let caller, args = rename_caller loc args caller in
    (* add statement tracking initialization of return values *)
    let env =
      match result with
      | Some lv when not (Functions.RTL.is_generated_kf kf) ->
        add_initializer loc lv ~post:false stmt env kf
      | _ ->
        env
    in
    Call(result, caller, args, loc), env

  | Local_init(vi, linit, loc) ->
    let lv = Var vi, NoOffset in
    let env = add_initializer loc ~vi lv ~post:true stmt env kf in
    let linit, env = inject_in_local_init loc env kf vi linit in
    Local_init(vi, linit, loc), env

  (* nothing to do: *)
  | Asm _
  | Skip _
  | Code_annot _ ->
    instr, env

let add_new_block_in_stmt env kf stmt =
  (* be careful: since this function is called in a post action, [env] has been
     modified from the time where pre actions have been executed.  Use
     [function_env] to get it back. *)
  (* [TODO ARCHI] what about the above comment? *)
  (* Add temporal analysis instrumentations *)
  let env = Temporal.handle_stmt stmt env kf in
  let new_stmt, env =
    if Functions.check kf then
      let env =
        (* handle ghost statement *)
        if stmt.ghost then begin
          stmt.ghost <- false;
          (* translate potential RTEs of ghost code *)
          let rtes = Rte.stmt ~warn:false kf stmt in
          Translate.translate_rte_annots Printer.pp_stmt stmt kf env rtes
        end else
          env
      in
      (* handle loop invariants *)
      let new_stmt, env = Loops.preserve_invariant env kf stmt in
      new_stmt, env
    else
      stmt, env
  in
  let mk_post_env env stmt =
    Annotations.fold_code_annot
      (fun _ a env -> Translate.translate_post_code_annotation kf env a)
      stmt
      env
  in
  let new_stmt, env =
    (* Remove local variables which scopes ended via goto/break/continue. *)
    let del_vars = Exit_points.delete_vars stmt in
    let env = Memory_observer.delete_from_set ~before:stmt env kf del_vars in
    if Kernel_function.is_return_stmt kf stmt then
      let env =
        if Functions.check kf then
          (* must generate the post_block before including [stmt] (the
             'return') since no code is executed after it. However, since
             this statement is pure (Cil invariant), that is semantically
             correct. *)
          (* [JS 2019/2/19] TODO: what about the other ways of early exiting
             a block? *)
          let env = mk_post_env env stmt in
          (* also handle the postcondition of the function and clear the
             env *)
          Translate.translate_post_spec kf env (Annotations.funspec kf)
        else
          env
      in
      (* de-allocating memory previously allocating by the kf *)
      (* remove recorded function arguments *)
      let fargs = Kernel_function.get_formals kf in
      let env = Memory_observer.delete_from_list env kf fargs in
      let b, env =
        Env.pop_and_get env new_stmt ~global_clear:true Env.After
      in
      if Kernel_function.is_main kf && Mmodel_analysis.use_model () then begin
        let stmts = b.bstmts in
        let l = List.rev stmts in
        match l with
        | [] -> assert false (* at least the 'return' stmt *)
        | ret :: l ->
          let loc = Stmt.loc stmt in
          let delete_stmts =
            Global_observer.mk_delete_stmts
              [ Constructor.mk_rtl_call ~loc "memory_clean" []; ret ]
          in
          b.bstmts <- List.rev l @ delete_stmts
      end;
      let new_stmt = Constructor.mk_block stmt b in
      if not (Cil_datatype.Stmt.equal stmt new_stmt) then begin
        (* move the labels of the return to the new block in order to
           evaluate the postcondition when jumping to them. *)
        E_acsl_label.move kf stmt new_stmt
      end;
      new_stmt, env
    else (* i.e. not (is_return stmt) *)
      (* must generate [pre_block] which includes [stmt] before generating
         [post_block] *)
      let pre_block, env =
        Env.pop_and_get
          ~split:true
          env
          new_stmt
          ~global_clear:false
          Env.After
      in
      let env =
        (* if [kf] is not monitored, do not translate any postcondition,
           but still push an empty environment consumed by
           [Env.pop_and_get] below. This [Env.pop_and_get] call is always
           required in order to generate the code not directly related to
           the annotations of the current stmt in anycase. *)
        if Functions.check kf then mk_post_env (Env.push env) stmt
        else Env.push env
      in
      let post_block, env =
        Env.pop_and_get
          env
          (Constructor.mk_block new_stmt pre_block)
          ~global_clear:false
          Env.Before
      in
      let post_block =
        if post_block.blocals = [] && new_stmt.labels = []
        then Cil.transient_block post_block
        else post_block
      in
      let res = Constructor.mk_block new_stmt post_block in
      if not (Cil_datatype.Stmt.equal new_stmt res) then
        E_acsl_label.move kf new_stmt res;
      res, env
  in
  Options.debug ~level:4
    "@[new stmt (from sid %d):@ %a@]" stmt.sid Printer.pp_stmt new_stmt;
  new_stmt, env

(* [TODO ARCHI] not sure returning the stmt_kind is useful;
   actually probably useful for printf-like functions.
   TO BE TESTED LATER *)
(* visit the substmts and build the new skind *)
let rec inject_in_substmt env kf stmt = match stmt.skind with
  | Instr instr ->
    let instr, env = inject_in_instr env kf stmt instr in
    Instr instr, env

  | Return(Some e, loc)  ->
    let e, env = replace_literal_string_in_exp env (Some kf) e in
    Return(Some e, loc), env

  | If(e, blk1, blk2, loc) ->
    let env = inject_in_block env kf blk1 in
    let env = inject_in_block env kf blk2 in
    let e, env = replace_literal_string_in_exp env (Some kf) e in
    If(e, blk1, blk2, loc), env

  | Switch(e, blk, stmts, loc) ->
    (* [blk] and [stmts] are visited at the same time *)
    let env = inject_in_block env kf blk in
    let e, env = replace_literal_string_in_exp env (Some kf) e in
    Switch(e, blk, stmts, loc), env

  | Loop(_ (* ignore AST annotations *), blk, loc, stmt_opt1, stmt_opt2) ->
    let env = inject_in_block env kf blk in
    let do_opt env = function
      | None -> None, env
      | Some stmt ->
        let stmt, env = inject_in_stmt env kf stmt in
        Some stmt, env
    in
    let stmt_opt1, env = do_opt env stmt_opt1 in
    let stmt_opt2, env = do_opt env stmt_opt2 in
    Loop([], blk, loc, stmt_opt1, stmt_opt2), env

  | Block blk as skind ->
    skind, inject_in_block env kf blk

  | UnspecifiedSequence l ->
    let l, env =
      List.fold_left
        (fun (l, env) (stmt, l1, l2, l3, srefs) ->
           let stmt, env = inject_in_stmt env kf stmt in
           (stmt, l1, l2, l3, srefs) :: l, env)
        ([], env)
        l
    in
    UnspecifiedSequence (List.rev l), env

  | Throw(Some(e, ty), loc) ->
    let e, env = replace_literal_string_in_exp env (Some kf) e in
    Throw(Some(e, ty), loc), env

  | TryCatch(blk, l, _loc) as skind ->
    let env = inject_in_block env kf blk in
    let env =
      List.fold_left
        (fun env (cb, blk) ->
           let env = inject_in_catch_binder env kf cb in
           inject_in_block env kf blk)
        env
        l
    in
    skind, env

  | TryFinally(blk1, blk2, _loc) as skind ->
    let env = inject_in_block env kf blk1 in
    let env = inject_in_block env kf blk2 in
    skind, env

  | TryExcept(_blk1, (_instrs, _e), _blk2, _loc) ->
    Error.not_yet "try ... except ..."

  (* nothing to do: *)
  | Throw(None, _)
  | Return(None, _)
  | Goto _ (* do not visit the internal stmt since it has already been handle *)
  | Break _
  | Continue _ as skind ->
    skind, env

and inject_in_stmt env kf stmt =
  Options.debug ~level:4
    "proceeding stmt (sid %d) %a@."
    stmt.sid Stmt.pretty stmt;
  (* pushing a new context *)
  let env = Env.push env in
  let env = match stmt.skind with
    | Loop _ -> Env.push_loop env
    | _ -> env
  in
  (* initial environment *)
  let env =
    if Kernel_function.is_first_stmt kf stmt then
      let env =
        if Kernel_function.is_main kf then
          env
        else
          let env =
            Memory_observer.store env kf (Kernel_function.get_formals kf)
          in
          Temporal.handle_function_parameters kf env
      in
      (* translate the precondition of the function *)
      if Functions.check kf then
        let funspec = Annotations.funspec kf in
        Translate.translate_pre_spec kf env funspec
      else env
    else
      env
  in
  (* translate code annotations *)
  let env =
    if Functions.check kf then
      Annotations.fold_code_annot
        (fun _ a env -> Translate.translate_pre_code_annotation kf env a)
        stmt
        env
    else
      env
  in
  (* add [__e_acsl_store_duplicate] calls for local variables which declarations
     are bypassed by gotos. Note: should be done before visiting instructions
     (which adds initializers), otherwise init calls appear before store
     calls. *)
  let duplicates = Exit_points.store_vars stmt in
  let env = Memory_observer.duplicate_store ~before:stmt env kf duplicates in
  let skind, env = inject_in_substmt env kf stmt in
  stmt.skind <- skind;
  (* building the new block of code *)
  add_new_block_in_stmt env kf stmt

and inject_in_block (env: Env.t) kf blk =
  let stmts, env =
    List.fold_left
      (fun (stmts, env) stmt ->
         let stmt, env = inject_in_stmt env kf stmt in
         stmt :: stmts, env)
      ([], env)
      blk.bstmts
  in
  blk.bstmts <- List.rev stmts;
  let free_stmts = At_with_lscope.Free.find_all kf in
  match blk.blocals, free_stmts with
  | [], [] ->
    env
  | [], _ :: _ | _ :: _, [] | _ :: _, _ :: _ ->
    let add_locals stmts =
      if Functions.instrument kf then
        List.fold_left
          (fun acc vi ->
             if Mmodel_analysis.must_model_vi ~kf vi
             then Constructor.mk_delete_stmt vi :: acc
             else acc)
          stmts
          blk.blocals
      else
        stmts
    in
    let rec insert_in_innermost_last_block blk = function
      | { skind = Return _ } as ret :: ((potential_clean :: tl) as l) ->
        (* keep the return (enclosed in a generated block) at the end;
           preceded by clean if any *)
        let init, tl =
          if Kernel_function.is_main kf && Mmodel_analysis.use_model () then
            free_stmts @ [ potential_clean; ret ], tl
          else
            free_stmts @ [ ret ], l
        in
        (* now that [free] stmts for [kf] have been inserted,
           there is no more need to keep the corresponding entries in the
           table managing them. *)
        At_with_lscope.Free.remove_all kf;
        blk.bstmts <-
          List.fold_left (fun acc v -> v :: acc) (add_locals init) tl
      | { skind = Block b } :: _ ->
        insert_in_innermost_last_block b (List.rev b.bstmts)
      | l ->
        blk.bstmts <- List.fold_left (fun acc v -> v :: acc) (add_locals []) l
    in
    insert_in_innermost_last_block blk (List.rev blk.bstmts);
    if Functions.instrument kf then
      blk.bstmts <-
        List.fold_left
          (fun acc vi ->
             if Mmodel_analysis.must_model_vi vi && not vi.vdefined
             then Constructor.mk_store_stmt vi :: acc
             else acc)
          blk.bstmts
          blk.blocals;
    env

and inject_in_catch_binder env kf = function
  | Catch_exn(_, l) ->
    List.fold_left (fun env (_, blk) -> inject_in_block env kf blk) env l
  | Catch_all ->
    env

(* ************************************************************************** *)
(* Function definition *)
(* ************************************************************************** *)

let add_generated_variables_in_function env fundec =
  let vars = Env.get_generated_variables env in
  let locals, blocks =
    List.fold_left
      (fun (local_vars, block_vars as acc) (v, scope) -> match scope with
         (* TODO: [kf] assumed to be consistent. Should be asserted. *)
         (* TODO: actually, is the kf as constructor parameter useful? *)
         | Env.LFunction _kf -> v :: local_vars, v :: block_vars
         | Env.LLocal_block _kf -> v :: local_vars, block_vars
         | _ -> acc)
      (fundec.slocals, fundec.sbody.blocals)
      vars
  in
  fundec.slocals <- locals;
  fundec.sbody.blocals <- blocks

(* Memory management for \at on purely logic variables: put [malloc] stmts at
   proper locations *)
let add_malloc_and_free_stmts kf fundec =
  let malloc_stmts = At_with_lscope.Malloc.find_all kf in
  let fstmts = malloc_stmts @ fundec.sbody.bstmts in
  fundec.sbody.bstmts <- fstmts;
  (* now that [malloc] stmts for [kf] have been inserted, there is no more need
     to keep the corresponding entries in the table managing them. *)
  At_with_lscope.Malloc.remove_all kf

let inject_in_fundec main fundec =
  let vi = fundec.svar in
  let kf = try Globals.Functions.get vi with Not_found -> assert false in
  (* convert ghost variables *)
  vi.vghost <- false;
  List.iter (fun vi -> vi.vghost <- false) fundec.slocals;
  (* update environments *)
  Builtins.update vi.vname vi;
  (* track function addresses but the main function that is tracked internally
     via RTL *)
  if not (Kernel_function.is_main kf) then Global_observer.add vi;
  (* exit point computations *)
  if Functions.instrument kf then Exit_points.generate fundec;
  Options.feedback ~dkey ~level:2 "entering in function %a."
    Kernel_function.pretty kf;
  (* recursive visit *)
  let env = inject_in_block Env.empty kf fundec.sbody in
  Exit_points.clear ();
  add_generated_variables_in_function env fundec;
  add_malloc_and_free_stmts kf fundec;
  (* setting main if necessary *)
  let main = if Kernel_function.is_main kf then Some fundec else main in
  Options.feedback ~dkey ~level:2 "function %a done."
    Kernel_function.pretty kf;
  env, main

(* ************************************************************************** *)
(* The whole AST *)
(* ************************************************************************** *)

let inject_in_global (env, main) = function
  (* library functions and built-ins *)
  | GVarDecl(vi, _) | GVar(vi, _, _)
  | GFunDecl(_, vi, _) | GFun({ svar = vi }, _)
    when Misc.is_library_loc vi.vdecl || Builtins.mem vi.vname ->
    Misc.register_library_function vi;
    if Builtins.mem vi.vname then Builtins.update vi.vname vi;
    env, main

  (* Cil built-ins and other library globals: nothing to do *)
  | GVarDecl(vi, _) | GVar(vi, _, _) | GFun({ svar = vi }, _)
    when Cil.is_builtin vi ->
    env, main
  | g when Misc.is_library_loc (Global.loc g) ->
    env, main

  (* variables and functions declarations *)
  | GVarDecl(vi, _) | GFunDecl(_, vi, _) ->
    (* do not convert extern ghost variables, because they can't be linked,
       see bts #1392 *)
    if vi.vstorage <> Extern then vi.vghost <- false;
    Global_observer.add vi;
    env, main

  (* variable definition *)
  | GVar(vi, { init = None }, _) ->
    Global_observer.add vi;
    vi.vghost <- false;
    env, main

  | GVar(vi, { init = Some init }, _) ->
    Global_observer.add vi;
    vi.vghost <- false;
    (* [TODO ARCHI] check that keeping changes in initializers is useless since
       all is done in place --> document why returning an expression is useful:
       what may change? *)
    let _, env = inject_in_init env None vi NoOffset init in
    env, main

  (* function definition *)
  | GFun(fundec, _) ->
    inject_in_fundec main fundec

  (* other globals: nothing to do *)
  | GType _
  | GCompTag _
  | GCompTagDecl _
  | GEnumTag _
  | GEnumTagDecl _
  | GAsm _
  | GPragma _
  | GText _
  | GAnnot _ (* do never read annotation from sources *)
    ->
    env, main

(* TODO: what about using [file.globalinit]? *)
let inject_global_initializer file main =
  Options.feedback ~dkey ~level:2 "building global initializer.";
  let vi, fundec = Global_observer.mk_init_function () in
  let cil_fct = GFun(fundec, Location.unknown) in
  if Mmodel_analysis.use_model () then begin
    match main with
    | Some main ->
      let exp = Cil.evar ~loc:Location.unknown vi in
      (* Create [__e_acsl_globals_init();] call *)
      let stmt =
        Cil.mkStmtOneInstr ~valid_sid:true
          (Call(None, exp, [], Location.unknown))
      in
      vi.vreferenced <- true;
      (* insert [__e_acsl_globals_init ();] as first statement of
         [main] *)
      main.sbody.bstmts <- stmt :: main.sbody.bstmts;
      let new_globals =
        List.fold_right
          (fun g acc -> match g with
             | GFun({ svar = vi }, _)
               when Varinfo.equal vi main.svar ->
               acc
             | _ -> g :: acc)
          file.globals
          [ cil_fct; GFun(main, Location.unknown) ]
      in
      (* add the literal string varinfos as the very first
         globals *)
      let new_globals =
        Literal_strings.fold
          (fun _ vi l ->
             GVar(vi, { init = None }, Location.unknown) :: l)
          new_globals
      in
      file.globals <- new_globals
    | None ->
      Kernel.warning "@[no entry point specified:@ \
                      you must call function `%s' and `__e_acsl_memory_clean by yourself.@]"
        Global_observer.function_name;
      file.globals <- file.globals @ [ cil_fct ]
  end

(* Add a call to [__e_acsl_memory_init] that initializes memory storage and
   potentially records program arguments. Parameters to [__e_acsl_memory_init]
   are addresses of program arguments or NULLs if [main] is declared without
   arguments. *)
let inject_mmodel_initializer main =
  let loc = Location.unknown in
  let nulls = [ Cil.zero loc ; Cil.zero loc ] in
  let handle_main main =
    let args =
      (* record arguments only if the second has a pointer type, so a argument
         strings can be recorded. This is sufficient to capture C99 compliant
         arguments and GCC extensions with environ. *)
      match main.sformals with
      | [] ->
        (* no arguments to main given *)
        nulls
      | _argc :: argv :: _ when Cil.isPointerType argv.vtype ->
        (* grab addresses of arguments for a call to the main initialization
           function, i.e., [__e_acsl_memory_init] *)
        List.map Cil.mkAddrOfVi main.sformals;
      | _ :: _ ->
        (* some non-standard arguments. *)
        nulls
    in
    let ptr_size = Cil.sizeOf loc Cil.voidPtrType in
    let args = args @ [ ptr_size ] in
    let init = Constructor.mk_rtl_call loc "memory_init" args in
    main.sbody.bstmts <- init :: main.sbody.bstmts
  in
  Extlib.may handle_main main

let inject_in_file file =
  let _env, main =
    List.fold_left inject_in_global (Env.empty, None) file.globals
  in
  (* post-treatment *)
  (* extend [main] with forward initialization and put it at end *)
  if not (Global_observer.is_empty () && Literal_strings.is_empty ()) then
    inject_global_initializer file main;
  file.globals <- Logic_functions.add_generated_functions file.globals;
  inject_mmodel_initializer main

let reset_all ast =
  Options.Run.off ();
  Misc.reset ();
  Logic_functions.reset ();
  Literal_strings.reset ();
  Global_observer.reset ();
  Typing.clear ();
  Cfg.clearFileCFG ~clear_id:false ast;
  Cfg.computeFileCFG ast;
  Ast.mark_as_grown ()

let inject () =
  Options.feedback ~level:2
    "injecting annotations as code in project %a"
    Project.pretty (Project.current ());
  Keep_status.before_translation ();
  Misc.reorder_ast ();
  let ast = Ast.get () in
  inject_in_file ast;
  reset_all ast;

(*
Local Variables:
compile-command: "make -C ../../../../.."
End:
*)
