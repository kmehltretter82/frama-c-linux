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

let check () =
  Visitor.visitFramacFileSameGlobals (Visit.do_visit false) (Ast.get ());
  let t = Error.nb_untypable () in
  let n = Error.nb_not_yet () in
  let print msg n =
    Options.result "@[%d annotation%s %s ignored,@ being %s.@]" 
      n
      (if n > 1 then "s" else "")
      (if n > 1 then "were" else "was")
      msg
  in
  print "untypable" t;
  print "unsupported" n;
  n + t = 0

let check =
  Dynamic.register
    ~plugin:"e-acsl"
    ~journalize:true
    "check"
    (Datatype.func Datatype.unit Datatype.bool)
    check

let extended_ast_project: Project.t option ref = ref None

let unmemoized_extend_ast () =
  let extend () =
    Options.feedback ~level:3 "setting kernel options for E-ACSL.";
    Kernel.CppExtraArgs.add
      (Pretty_utils.sfprintf " -DE_ACSL_MACHDEP=%s -I%s/libc" 
	 (Kernel.Machdep.get ())
	 Config.datadir);
    Kernel.Keep_unused_specified_functions.off ();
    let register s =
      File.pre_register
	(File.NeedCPP 
	   (s, 
	    File.get_preprocessor_command () 
	    ^ Pretty_utils.sfprintf " -I%s" 
	      (Options.Share.dir ~error:true ())))
    in
    List.iter register (Misc.library_files ())
  in
  if Ast.is_computed () then begin
    (* do not modify the existing project: work on a copy.
       Must also extend the current AST with the E-ACSL's library files. *)
    Options.feedback ~level:2 "AST already computed: \
E-ACSL is going to work on a copy.";
    let name = Project.get_name (Project.current ()) in
    let tmpfile = 
      Extlib.temp_file_cleanup_at_exit ("e_acsl_" ^ name) ".i" in
    let cout = open_out tmpfile in
    let fmt = Format.formatter_of_out_channel cout in
    File.pretty_ast ~fmt ();
    let selection = 
      State_selection.diff
	State_selection.full
	(State_selection.with_dependencies Ast.self)
    in
    let prj =
      Project.create_by_copy
	~selection
	(Pretty_utils.sfprintf "%s for E-ACSL" name)
    in
    Project.on prj
      (fun () ->
	Kernel.Files.set [ tmpfile ];
	extend ())
      ();
    prj
  end else begin
    extend ();
    Project.current ()
  end

let extend_ast () = match !extended_ast_project with
  | None -> 
    let prj = unmemoized_extend_ast () in
    extended_ast_project := Some prj;
    prj
  | Some prj ->
    prj

let apply_on_e_acsl_ast f x =
  let tmp_prj = extend_ast () in
  let res = Project.on tmp_prj f x in
  if not (Project.equal tmp_prj (Project.current ())) then begin
    extended_ast_project := None;
    Project.remove ~project:tmp_prj ()
  end;
  res

module Resulting_projects =
  State_builder.Hashtbl
    (Datatype.String.Hashtbl)
    (Project.Datatype)
    (struct
      let name = "E-ACSL resulting projects"
      let size = 7
      let dependencies = [ Ast.self ]
     end)

let () = Env.global_state := Resulting_projects.self

let generate_code =
  Resulting_projects.memo
    (fun name ->
      apply_on_e_acsl_ast
	(fun () ->
	  Options.feedback "beginning translation.";
	  let dup_prj = Pre_visit.dup_functions () in
	  let res =
	    Project.on
	      dup_prj
	      (fun () ->
		Pre_analysis.init_mpz ();
		Pre_analysis.reset ();
		let visit prj = Visit.do_visit ~prj true in
		let prj = File.create_project_from_visitor name visit in
		Resulting_projects.mark_as_computed ();
		prj)
	      ()
	  in
	  Project.remove ~project:dup_prj ();
	  Options.feedback "translation done in project \"%s\"." 
	    (Options.Project_name.get ());
	  res)
	())

let generate_code =
  Dynamic.register
    ~plugin:"E_ACSL"
    ~journalize:true
    "generate_code"
    (Datatype.func Datatype.string Project.ty)
    generate_code

let predicate_to_exp =
  Dynamic.register
    ~plugin:"E_ACSL"
    ~journalize:false
    "predicate_to_exp"
    (Datatype.func2
       Kernel_function.ty Cil_datatype.Predicate_named.ty Cil_datatype.Exp.ty)
    Translate.predicate_to_exp

let add_e_acsl_library _files = 
  if Options.must_visit () || Options.Prepare.get () then ignore (extend_ast ())

(* extending the AST as soon as possible reduce the amount of time the AST is
   duplicated:
   - that is faster
   - locations are better (indicate an existing file, and not a temp file) *)
let () = Cmdline.run_after_configuring_stage add_e_acsl_library

let main () =
  if Options.Run.get () then
    ignore (generate_code (Options.Project_name.get ()))
  else
    if Options.Check.get () then
      apply_on_e_acsl_ast
	(fun () -> 
	  Pre_analysis.init_mpz ();
	  ignore (check ()))
	()

let () = Db.Main.extend main

(*
Local Variables:
compile-command: "make"
End:
*)
