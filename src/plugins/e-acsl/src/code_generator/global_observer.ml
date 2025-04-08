(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Cil_types
open Cil_datatype

let function_init_name = Functions.RTL.mk_api_name "globals_init"
let function_clean_name = Functions.RTL.mk_api_name "globals_clean"

(* Hashtable mapping global variables (as Cil_type.varinfo) to their
   initializers (if any).

   NOTE: here, varinfos as keys belong to the original project while values
   belong to the new one *)
let tbl
  : (offset (* compound initializers *) * init) list ref Varinfo.Hashtbl.t
  = Varinfo.Hashtbl.create 7

let reset () = Varinfo.Hashtbl.reset tbl

let is_empty () = Varinfo.Hashtbl.length tbl = 0

(* Make a unique mapping for each global variable omitting initializers.
   Initializers (used to capture literal strings) are added through
   [add_initializer] below. *)
let add vi =
  if Memory_tracking.must_monitor_vi vi then
    Varinfo.Hashtbl.replace tbl vi (ref [])

let add_initializer vi offset init =
  if Memory_tracking.must_monitor_vi vi then
    try
      let l = Varinfo.Hashtbl.find tbl vi in
      l := (offset, init) :: !l
    with Not_found ->
      Options.fatal "variable %a is not monitored" Printer.pp_varinfo vi

(* Create a global kernel function named [name].
   Return a triple (varinfo * fundec * kernel_function) of the created
   global function. *)
let mk_function name =
  (* Create global function [name] *)
  let vi =
    Cil.makeGlobalVar ~source:true
      name
      Cil_const.(mk_tfun voidType (Some []) false)
  in
  vi.vdefined <- true;
  (* There is no contract associated with the function *)
  let spec = Cil.empty_funspec () in
  (* Create function definition with no stmt yet: they will be added
     afterwards *)
  let blk = Cil.mkBlock [] in
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
  let fct = Definition(fundec, Location.unknown) in
  (* Create and register the function as kernel function *)
  let kf = { fundec = fct; spec = spec } in
  Globals.Functions.register kf;
  Globals.Functions.replace_by_definition spec fundec Location.unknown;
  vi, fundec, kf

let mk_init_function () =
  (* Create and register [__e_acsl_globals_init] function with definition
     for initialization of global variables *)
  let vi, fundec, _ = mk_function function_init_name in
  (* Now generate the statements. The generation is done only now because it
     depends on the local variable [already_run] whose generation required the
     existence of [fundec] *)
  let env = Env.push Env.empty in
  (* allocation and initialization of globals *)
  let stmts =
    Varinfo.Hashtbl.fold_sorted
      (fun vi _ stmts ->
         if Misc.is_fc_or_compiler_builtin vi then stmts
         else
           (* a global is both allocated and initialized *)
           Smart_stmt.store_stmt vi
           :: Smart_stmt.initialize ~loc:Location.unknown (Cil.var vi)
           :: stmts)
      tbl
      []
  in
  (* create a new code block with generated statements *)
  let b, stmts = match stmts with
    | [] -> assert false
    | stmt :: stmts ->
      let b, _env = Env.pop_and_get env stmt ~global_clear:true Env.Before in
      b, stmts
  in
  let stmts = Smart_stmt.block_stmt b :: stmts in
  (* prevent multiple calls to [__e_acsl_globals_init] *)
  let loc = Location.unknown in
  let vi_already_run =
    Cil.makeLocalVar
      fundec
      (Functions.RTL.mk_api_name "already_run")
      Cil_const.charType
  in
  vi_already_run.vdefined <- true;
  vi_already_run.vreferenced <- true;
  vi_already_run.vstorage <- Static;
  let init = AssignInit (SingleInit (Cil.zero ~loc)) in
  let init_stmt =
    Cil.mkStmtOneInstr ~valid_sid:true
      (Local_init (vi_already_run, init, loc))
  in
  let already_run =
    Smart_stmt.assigns
      ~loc
      ~result:(Cil.var vi_already_run)
      (Cil.one ~loc)
  in
  let stmts = already_run :: stmts in
  let guard =
    Smart_stmt.if_stmt
      ~loc
      ~cond:(Cil.evar vi_already_run)
      (Cil.mkBlock [])
      ~else_blk:(Cil.mkBlock stmts)
  in
  let return = Cil.mkStmt ~valid_sid:true (Return (None, loc)) in
  let stmts = [ init_stmt; guard; return ] in
  fundec.sbody.bstmts <- stmts;
  vi, fundec

let mk_clean_function () =
  if Varinfo.Hashtbl.length tbl = 0 then
    None
  else
    (* Create and register [__e_acsl_globals_clean] function with definition
       for de-allocation of global variables *)
    let vi, fundec, _kf = mk_function function_clean_name in
    (* Generate delete statements and add them to the function body *)
    let return = Cil.mkStmt ~valid_sid:true (Return (None, Location.unknown)) in
    let stmts =
      Varinfo.Hashtbl.fold_sorted
        (fun vi _l acc ->
           if Misc.is_fc_or_compiler_builtin vi then acc
           else Smart_stmt.delete_stmt vi :: acc)
        tbl
        [return]
    in
    fundec.sbody.bstmts <- stmts;
    Some (vi, fundec)
