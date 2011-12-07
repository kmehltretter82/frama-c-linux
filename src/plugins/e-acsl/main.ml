(**************************************************************************)
(*                                                                        *)
(*  This file is part of the E-ACSL plug-in of Frama-C.                   *)
(*                                                                        *)
(*  Copyright (C) 2011                                                    *)
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
  try
    Visitor.visitFramacFileSameGlobals (Visit.do_visit false) (Ast.get ());
    true
  with Misc.Typing_error s ->
    Options.error ~current:true "%s" s;
    false

let check =
  Dynamic.register
    ~plugin:"e-acsl"
    ~journalize:true
    "check"
    (Datatype.func Datatype.unit Datatype.bool)
    check

let fail_check () =
  try Visitor.visitFramacFileSameGlobals (Visit.do_visit false) (Ast.get ());
  with Misc.Typing_error s -> Options.abort ~current:true "%s" s

let fail_check =
  Dynamic.register
    ~plugin:"e-acsl"
    ~journalize:true
    "fail_check"
    (Datatype.func Datatype.unit Datatype.unit)
    fail_check

module Resulting_projects =
  State_builder.Hashtbl
    (Datatype.String.Hashtbl)
    (Project.Datatype)
    (struct
      let name = "E-ACSL resulting projects"
      let size = 7
      let kind = `Correctness
      let dependencies = [ Ast.self; Options.Use_assert.self ]
     end)

let () = Env.global_state := Resulting_projects.self

let generate_code =
  Resulting_projects.memo
    (fun name ->
      try
	let visit prj = Visit.do_visit ~prj true in
	File.create_rebuilt_project_from_visitor ~preprocess:false name visit
      with Misc.Typing_error s ->
	Options.abort ~current:true "%s" s)

let generate_code =
  Dynamic.register
    ~plugin:"e-acsl"
    ~journalize:true
    "generate_code"
    (Datatype.func Datatype.string Project.ty)
    generate_code

let main () =
  if Options.Run.get () then 
    ignore (generate_code (Options.Project_name.get ()))
  else
    if Options.Check.get () then fail_check () 

let () = Db.Main.extend main

(*
Local Variables:
compile-command: "make"
End:
*)
