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
      let help = "abort on E-ACSL type checking error"
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

module Use_assert =
  False
    (struct
      let option_name = "-e-acsl-use-assert"
      let help = "use C macro `assert' instead of `exit' in the new project \
(by default, use it whenever possible)"
      let kind = `Correctness
     end)

(*
Local Variables:
compile-command: "make"
End:
*)
