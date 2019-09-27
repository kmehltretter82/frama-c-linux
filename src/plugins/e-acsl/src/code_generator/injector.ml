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

open Cil_types
open Cil_datatype

let dkey = Options.dkey_translation

(* [TODO ARCHI] move it in another module *)
let is_main kf =
  Datatype.String.equal (Kernel_function.get_name kf) "main"

(* ************************************************************************** *)
(* Code *)
(* ************************************************************************** *)

let inject_in_block _env _main kf blk =
  (* [TODO ARCHI] HERE recursive call *)
  let free_stmts = At_with_lscope.Free.find_all kf in
  match blk.blocals, free_stmts with
  | [], [] ->
    ()
  | [], _ :: _ | _ :: _, [] | _ :: _, _ :: _ ->
    let add_locals stmts =
      if Functions.instrument kf then
        List.fold_left
          (fun acc vi ->
             if Mmodel_analysis.must_model_vi ~kf vi then
               Misc.mk_delete_stmt vi :: acc
             else
               acc)
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
          if is_main kf && Mmodel_analysis.use_model () then
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
             then Misc.mk_store_stmt vi :: acc
             else acc)
          blk.bstmts
          blk.blocals

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

let inject_in_fundec env main fundec =
  let vi = fundec.svar in
  let kf = try Globals.Functions.get vi with Not_found -> assert false in
  (* convert ghost variables *)
  vi.vghost <- false;
  List.iter (fun vi -> vi.vghost <- false) fundec.slocals;
  (* update environments *)
  Builtins.update vi.vname vi;
  if is_main kf then Global_observer.add vi;
  (* exit point computations *)
  if Functions.instrument kf then Exit_points.generate fundec;
  Options.feedback ~dkey ~level:2 "entering in function %a."
    Kernel_function.pretty kf;
  (* recursive visit *)
  inject_in_block env main kf fundec.sbody;
  Exit_points.clear ();
  add_generated_variables_in_function env fundec;
  add_malloc_and_free_stmts kf fundec;
  (* setting main if necessary *)
  let main = if is_main kf then Some fundec else main in
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
    env, main

  (* variable definition *)
  | GVar(vi, _initinfo, _) ->
    vi.vghost <- false;
    (* [TODO ARCHI] init_info *)
    env, main

  (* function definition *)
  | GFun(fundec, _) ->
    inject_in_fundec env main fundec

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
let inject_global_initializer env file main =
  Options.feedback ~dkey ~level:2 "building global initializer.";
  (* [TODO ARCHI] is env really useless? *)
  let vi, fundec, _env = Global_observer.mk_init_function env in
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
    let name = Functions.RTL.mk_api_name "memory_init" in
    let init = Misc.mk_call loc name args in
    main.sbody.bstmts <- init :: main.sbody.bstmts
  in
  Extlib.may handle_main main

let inject_in_file file =
  let env, main =
    List.fold_left inject_in_global (Env.empty, None) file.globals
  in
  (* post-treatment *)
  (* extend [main] with forward initialization and put it at end *)
  if not (Global_observer.is_empty () && Literal_strings.is_empty ()) then
    inject_global_initializer env file main;
  file.globals <- Logic_functions.add_generated_functions file.globals;
  inject_mmodel_initializer main

let reset_all () =
  Misc.reset ();
  Logic_functions.reset ();
  Literal_strings.reset ();
  Global_observer.reset ();
  Keep_status.before_translation ()

let inject () =
  Options.feedback ~level:2
    "injecting annotations as code in project %a"
    Project.pretty (Project.current ());
  reset_all ();
  Misc.reorder_ast ();
  let ast = Ast.get () in
  inject_in_file ast;
  (* [TODO ARCHI] not consistent with the [reset_all] strategy: *)
  Typing.clear ()

(*
Local Variables:
compile-command: "make -C ../.."
End:
*)
