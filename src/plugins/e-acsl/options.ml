(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2010                                               *)
(*    CEA (Commissariat à l'Énergie Atomique)                             *)
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
      let help = "only perform E-ACSL type checking"
      let kind = `Correctness
     end)

module Project_name =
  EmptyString
    (struct
      let option_name = "-e-acsl-runtime"
      let help = "generate a new project <prj> from the C program where E-ACSL \
 code is transformed to C code for runtime assertion checking"
      let kind = `Correctness
      let arg_name = "prj"
     end)

(*
Local Variables:
compile-command: "make"
End:
*)
