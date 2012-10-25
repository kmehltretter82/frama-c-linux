(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012                                                    *)
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
      Pre_analysis.reset ();
      let visit prj = Visit.do_visit ~prj true in
      File.create_project_from_visitor(* ~preprocess:false*) name visit)

let generate_code =
  Dynamic.register
    ~plugin:"e-acsl"
    ~journalize:true
    "generate_code"
    (Datatype.func Datatype.string Project.ty)
    generate_code

let add_e_acsl_library () =
  if Options.must_visit () then begin
    Kernel.CppExtraArgs.add (Pretty_utils.sfprintf " -I%s/libc" Config.datadir);
    Kernel.Keep_unused_specified_functions.off ();
    let register s =
      File.pre_register
	(File.NeedCPP 
	   (s, 
	    File.get_preprocessor_command () 
	    ^ Pretty_utils.sfprintf " -I%s" (Options.Share.dir ~error:true ())))
    in
    List.iter register (Misc.library_files ())
  end
 
let () = Cmdline.run_after_configuring_stage add_e_acsl_library

let main () =
  if Options.must_visit () then Pre_analysis.init_mpz ();
  if Options.Run.get () then
    ignore (generate_code (Options.Project_name.get ()))
  else
    if Options.Check.get () then ignore (check ())

let () = Db.Main.extend main

(*
Local Variables:
compile-command: "make"
End:
*)
