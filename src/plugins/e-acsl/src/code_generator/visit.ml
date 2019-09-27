(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2019                                               *)
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

module E_acsl_label = Label

(* ************************************************************************** *)
(* Visitor *)
(* ************************************************************************** *)

(* local references to the below visitor and to [do_visit] *)
let dft_funspec = Cil.empty_funspec ()
let funspec = ref dft_funspec

(* the main visitor performing e-acsl checking and C code generator *)
class e_acsl_visitor prj generate = object (self)

  inherit Visitor.generic_frama_c_visitor
    (if generate then Visitor_behavior.copy prj else Visitor_behavior.inplace ())

  val mutable is_initializer = false
  (* Global flag set to [true] if a currently visited node
     belongs to a global initializer and set to [false] otherwise *)

  (* Add mappings from global variables to their initializers in [global_vars].
     Note that the below function captures only [SingleInit]s. All compound
     initializers containing SingleInits (except for empty compound
     initializers) are unrapped and thrown away. *)
  method !vinit vi off _ =
    if generate then
      if Mmodel_analysis.must_model_vi vi then begin
        is_initializer <- vi.vglob;
        Cil.DoChildrenPost
          (fun i ->
            (match is_initializer with
            | true ->
              (match i with
              | CompoundInit(_,[]) ->
                (* Case of an empty CompoundInit, treat it as if there were
                   no initializer at all *)
                ()
              | CompoundInit(_,_) | SingleInit _ ->
                (* TODO: [off] should be the one of the new project while it is
                   from the old project *)
                Global_observer.add_initializer vi off i)
            | false-> ());
            is_initializer <- false;
          i)
      end else
        Cil.JustCopy
    else
      Cil.SkipChildren

  method !vvdec vi =
    (try
       let old_vi = Visitor_behavior.Get_orig.varinfo self#behavior vi in
       let old_kf = Globals.Functions.get old_vi in
       funspec :=
         Cil.visitCilFunspec
         (self :> Cil.cilVisitor)
         (Annotations.funspec old_kf)
     with Not_found ->
       ());
    Cil.SkipChildren

  method private is_return old_kf stmt =
    let old_ret =
      try Kernel_function.find_return old_kf
      with Kernel_function.No_Statement -> assert false
    in
    Stmt.equal stmt (Visitor_behavior.Get.stmt self#behavior old_ret)

  method private is_first_stmt old_kf stmt =
    try
      Stmt.equal
        (Visitor_behavior.Get_orig.stmt self#behavior stmt)
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
        let env =
          if generate && not is_main then
            let env =
              Memory_observer.store env kf (Kernel_function.get_formals kf)
            in
            Temporal.handle_function_parameters kf env
          else
            env
        in
        (* translate the precondition of the function *)
        if Functions.check kf then
          Project.on prj (Translate.translate_pre_spec kf env) !funspec
        else
          env
      else
        env
    in

    let env, new_annots =
      if Functions.check kf then
        Annotations.fold_code_annot
          (fun _ old_a (env, new_annots) ->
            let a =
              (* [VP] Don't use Visitor here, as it will fill the queue in the
                 middle of the computation... *)
              Cil.visitCilCodeAnnotation (self :> Cil.cilVisitor) old_a
            in
            let env =
              Project.on prj (Translate.translate_pre_code_annotation kf env) a
            in
            env, a :: new_annots)
          (Visitor_behavior.Get_orig.stmt self#behavior stmt)
          (env, [])
      else
        env, []
    in

    (* Add [__e_acsl_store_duplicate] calls for local variables which
     * declarations are bypassed by gotos. Note: should be done before
     * [vinst] method (which adds initializers) is executed, otherwise
     * init calls appear before store calls. *)
    let duplicates = Exit_points.store_vars stmt in
    let env =
      if generate
      then Memory_observer.duplicate_store ~before:stmt env kf duplicates
      else env
    in
    function_env := env;

    let mk_block stmt =
      (* be careful: since this function is called in a post action, [env] has
         been modified from the time where pre actions have been executed.
         Use [function_env] to get it back. *)
      let env = !function_env in
      let env =
        if generate then
          (* Add temporal analysis instrumentations *)
          let env = Temporal.handle_stmt stmt env in
          (* Add initialization statements and store_block statements stemming
             from Local_init *)
          self#handle_instructions stmt env kf
        else
          env
      in
      let new_stmt, env, must_mv =
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
          let new_stmt, env, must_mv =
            Loops.preserve_invariant prj env kf stmt
          in
          let orig = Visitor_behavior.Get_orig.stmt self#behavior stmt in
          Visitor_behavior.Set_orig.stmt self#behavior new_stmt orig;
          Visitor_behavior.Set.stmt self#behavior orig new_stmt;
          new_stmt, env, must_mv
        else
          stmt, env, false
      in
      let mk_post_env env =
        (* [fold_right] to preserve order of generation of pre_conditions *)
        Project.on
          prj
          (List.fold_right
             (fun a env -> Translate.translate_post_code_annotation kf env a)
             new_annots)
          env
      in
      let new_stmt, env =
        (* Remove local variables which scopes ended via goto/break/continue. *)
        let del_vars = Exit_points.delete_vars stmt in
        let env =
          if generate
          then Memory_observer.delete_from_set ~before:stmt env kf del_vars
          else env
        in
        if self#is_return kf stmt then
          let env =
            if Functions.check kf then
              (* must generate the post_block before including [stmt] (the
                 'return') since no code is executed after it. However, since
                 this statement is pure (Cil invariant), that is semantically
                 correct. *)
              (* [JS 2019/2/19] TODO: what about the other ways of early exiting
                 a block? *)
              let env = mk_post_env env in
              (* also handle the postcondition of the function and clear the
                 env *)
              Project.on prj (Translate.translate_post_spec kf env) !funspec
            else
              env
          in
          (* de-allocating memory previously allocating by the kf *)
          (* JS: should be done in the new project? *)
          if generate then
            (* Remove recorded function arguments *)
            let fargs = Kernel_function.get_formals kf in
            let env =
              if generate then Memory_observer.delete_from_list env kf fargs
              else env
            in
            let b, env =
              Env.pop_and_get env new_stmt ~global_clear:true Env.After
            in
            if is_main && Mmodel_analysis.use_model () then begin
              let stmts = b.bstmts in
              let l = List.rev stmts in
              let mclean = (Functions.RTL.mk_api_name "memory_clean") in
              match l with
              | [] -> assert false (* at least the 'return' stmt *)
              | ret :: l ->
                let loc = Stmt.loc stmt in
                let delete_stmts =
                  Global_observer.mk_delete
                    self#behavior
                    [ Misc.mk_call ~loc mclean []; ret ]
                in
                b.bstmts <- List.rev l @ delete_stmts
            end;
            let new_stmt = Misc.mk_block prj stmt b in
            if not (Cil_datatype.Stmt.equal stmt new_stmt) then begin
              (* move the labels of the return to the new block in order to
                 evaluate the postcondition when jumping to them. *)
              E_acsl_label.move
                (self :> Visitor.generic_frama_c_visitor) stmt new_stmt
            end;
            new_stmt, env
          else
            stmt, env
        else (* i.e. not (is_return stmt) *)
          if generate then begin
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
              if Functions.check kf then mk_post_env (Env.push env)
              else Env.push env
            in
            let post_block, env =
              Env.pop_and_get
                env
                (Misc.mk_block prj new_stmt pre_block)
                ~global_clear:false
                Env.Before
            in
            let post_block =
              if post_block.blocals = [] && new_stmt.labels = []
              then Cil.transient_block post_block
              else post_block
            in
            let res = Misc.mk_block prj new_stmt post_block in
            if not (Cil_datatype.Stmt.equal new_stmt res) then
              E_acsl_label.move (self :> Visitor.generic_frama_c_visitor)
                new_stmt res;
            let orig = Visitor_behavior.Get_orig.stmt self#behavior stmt in
            Visitor_behavior.Set.stmt self#behavior orig res;
            Visitor_behavior.Set_orig.stmt self#behavior res orig;
            res, env
          end else
            stmt, env
      in
      if must_mv then Loops.mv_invariants env ~old:new_stmt stmt;
      function_env := env;
      Options.debug ~level:4
      "@[new stmt (from sid %d):@ %a@]" stmt.sid Printer.pp_stmt new_stmt;
      if generate then new_stmt else stmt
    in
    Cil.ChangeDoChildrenPost(stmt, mk_block)

  method private handle_instructions stmt env kf =
    let add_initializer loc ?vi lv ?(post=false) stmt env kf =
      assert generate;
      if Functions.instrument kf then
        let may_safely_ignore = function
          | Var vi, NoOffset -> vi.vglob || vi.vformal
          | _ -> false
        in
        let must_model = Mmodel_analysis.must_model_lval ~stmt ~kf lv in
        if not (may_safely_ignore lv) && must_model then
          let before = Cil.mkStmt stmt.skind in
          let new_stmt =
            (* Bitfields are not yet supported ==> no initializer.
               A not_yet will be raised in [Translate]. *)
            if Cil.isBitfield lv then Project.on prj Cil.mkEmptyStmt ()
            else Project.on prj (Misc.mk_initialize ~loc) lv
          in
          let env = Env.add_stmt ~post ~before env new_stmt in
          let env = match vi with
            | None -> env
            | Some vi ->
              let new_stmt = Project.on prj Misc.mk_store_stmt vi in
              Env.add_stmt ~post ~before env new_stmt
          in
          env
        else
          env
      else
        env
    in
    let check_formats = Options.Validate_format_strings.get () in
    let replace_libc_fn = Options.Replace_libc_functions.get () in
    match stmt.skind with
    | Instr(Set(lv, _, loc)) -> add_initializer loc lv stmt env kf
    | Instr(Local_init(vi, init, loc)) ->
      let lv = (Var vi, NoOffset) in
      let env = add_initializer loc ~vi lv ~post:true stmt env kf in
      (* Handle variable-length array allocation via [__fc_vla_alloc].
         Here each instance of [__fc_vla_alloc] is rewritten to [alloca]
         (that is used to implement VLA) and further a custom call to
         [store_block] tracking VLA allocation is issued. *)
      (* KV: Do not add handling [alloca] allocation here (or anywhere else for
         that matter). Handling of [alloca] should be implemented in Frama-C
         (eventually). This is such that each call to [alloca] becomes
         [__fc_vla_alloc]. It is already handled using the code below. *)
      (match init with
       | ConsInit (fvi, sz :: _, _)
         when Functions.Libc.is_vla_alloc_name fvi.vname ->
        fvi.vname <- Functions.Libc.actual_alloca;
        (* Since we need to pass [vi] by value cannot use [Misc.mk_store_stmt]
           here. Do it manually. *)
        let sname = Functions.RTL.mk_api_name "store_block" in
        let store = Misc.mk_call ~loc sname [ Cil.evar vi ; sz ] in
        Env.add_stmt ~post:true env store
      (* Rewrite format functions (e.g., [printf]). See some comments below *)
      | ConsInit (fvi, args, knd) when check_formats
          && Functions.Libc.is_printf_name fvi.vname ->
        let name = Functions.RTL.get_rtl_replacement_name fvi.vname in
        let new_vi = Misc.get_lib_fun_vi name in
        let fmt = Functions.Libc.get_printf_argument_str ~loc fvi.vname args in
        stmt.skind <-
          Instr(Local_init(vi, ConsInit(new_vi, fmt :: args, knd), loc));
        env
      (* Rewrite names of functions for which we have alternative
        definitions in the RTL. *)
      | ConsInit (fvi, _, _) when replace_libc_fn &&
        Functions.RTL.has_rtl_replacement fvi.vname ->
        fvi.vname <- Functions.RTL.get_rtl_replacement_name fvi.vname;
        env
      | _ -> env)
    | Instr(Call (result, exp, args, loc)) ->
      (* Rewrite names of functions for which we have alternative
         definitions in the RTL. *)
      (match exp.enode with
      | Lval(Var vi, _) when replace_libc_fn &&
          Functions.RTL.has_rtl_replacement vi.vname ->
        vi.vname <- Functions.RTL.get_rtl_replacement_name vi.vname
      | Lval(Var vi , _) when Functions.Libc.is_vla_free_name vi.vname ->
        (* Handle variable-length array allocation via [__fc_vla_free].
           Rewrite its name to [delete_block]. The rest is in place. *)
        vi.vname <- Functions.RTL.mk_api_name "delete_block"
      | Lval(Var vi, _)
        when check_formats && Functions.Libc.is_printf_name vi.vname ->
        (* Rewrite names of format functions (such as printf). This case
           differs from the above because argument list of format functions is
           extended with an argument describing actual variadic arguments *)
        (* Replacement name, e.g., [printf] -> [__e_acsl_builtin_printf] *)
        let name = Functions.RTL.get_rtl_replacement_name vi.vname in
        (* Variadic arguments descriptor *)
        let fmt = Functions.Libc.get_printf_argument_str ~loc vi.vname args in
        (* get the name of the library function we need. Cannot just rewrite
           the name as AST check will then fail *)
        let vi = Misc.get_lib_fun_vi name in
        stmt.skind <- Instr(Call (result, Cil.evar vi, fmt :: args, loc))
      | _ -> ());
      (* Add statement tracking initialization of return values of function
         calls *)
      (match result with
        | Some lv when not (Functions.RTL.is_generated_kf kf) ->
          add_initializer loc lv ~post:false stmt env kf
        | _ -> env)
    | _ -> env

  (* Processing expressions for the purpose of replacing literal strings found
   in the code with variables generated by E-ACSL. *)
  method !vexpr _ =
    if generate then begin
      match is_initializer with
      (* Do not touch global initializers because they accept only constants *)
      | true -> Cil.DoChildren
      (* Replace literal strings elsewhere *)
      | false ->
        Cil.DoChildrenPost
          (fun e ->
            let e, env = Literal_observer.exp !function_env e in
            function_env := env;
            e)
    end else
      Cil.SkipChildren

end

(*
Local Variables:
compile-command: "make -C ../.."
End:
*)
