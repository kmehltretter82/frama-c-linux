(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2019                                               *)
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

let name = "Builtin"
let shortname = "builtin"

include Plugin.Register
    (struct
      let name = name
      let shortname = shortname
      let help = "Overrides standard library functions"
    end)

module Enabled = False
    (struct
      let option_name = "-" ^ shortname
      let help = ""
    end)

module Kfs =
  Kernel_function_set
    (struct
      let option_name = "-" ^ shortname ^ "-fct"
      let arg_name = "f,..."
      let help = "Override stdlib functions only into the specified functions (defaults to all)."
    end)

module NewBuiltin (B: sig val function_name: string end) = True
    (struct
      let option_name = "-" ^ shortname ^ "-" ^ B.function_name
      let help = "Activate replacement for function '" ^ B.function_name ^ "'"
    end)

let emitter = Emitter.create shortname [Emitter.Funspec] ~correctness:[] ~tuning:[]
