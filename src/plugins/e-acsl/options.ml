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

module P = Plugin.Register
  (struct
     let name = "E-ACSL"
     let shortname = "e-acsl"
     let help = "Executable ANSI/ISO C Specification Language --- runtime \
assertion checker generator"
   end)
include P

module Check =
  False
    (struct
      let option_name = "-e-acsl-check"
      let help = "only type check E-ACSL annotated program"
      let kind = `Correctness
     end)

module Run =
  False
    (struct
      let option_name = "-e-acsl"
      let help = "generate a new project where E-ACSL annotations are \
translated to executable C code"
      let kind = `Correctness
      let arg_name = "prj"
     end)

module Project_name =
  String
    (struct
      let option_name = "-e-acsl-project"
      let help = "the name of the generated project is <prj> \
(default to \"e-acsl\")"
      let kind = `Correctness
      let default = "e-acsl"
      let arg_name = "prj"
     end)

let () = Plugin.set_group help
module Version =
  False
    (struct
      let option_name = "-e-acsl-version"
      let help = "version of plug-in E-ACSL"
      let kind = `Tuning
     end)

let version () =
  if Version.get () then begin
    Log.print_on_output 
      (fun fmt -> 
	Format.fprintf 
	  fmt
	  "Version of plug-in E-ACSL: %s@?"
	  Local_config.version);
    raise Cmdline.Exit
  end
let () = Cmdline.run_after_configuring_stage version

(*
Local Variables:
compile-command: "make"
End:
*)
