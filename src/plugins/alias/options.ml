(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2023                                               *)
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

(* -------------------------------------------------------------------------- *)
(* --- Plugin Registration                                                --- *)
(* -------------------------------------------------------------------------- *)

include Plugin.Register
    (struct
      let name = "Alias Analysis"
      let help = "Lightweight May-Alias Analysis"
      let shortname = "alias"
    end)


module Enabled = False
    (struct
      let option_name = "-alias"
      let help = "Allows May-Alias Analyzer"
    end)


module ShowFunctionTable = False
    (struct
      let option_name = "-alias-show-function-table"
      let help = "Displays the table [function -> summary] at the end of the analysis"
    end)


module ShowStmtTable = False
    (struct
      let option_name = "-alias-show-stmt-table"
      let help = "Displays the table [stmt -> abstract state] at the end of the analysis"
    end)


module DebugTable = False
    (struct
      let option_name = "-alias-debug-table"
      let help = "switch to debug mode when printing Statement or Function Tables (with options -alias-show-stmt-table and -alias-show-function-table)"
    end)


module Dot_output =
  Empty_string
    (struct
      let option_name = "-alias-dot-output"
      let arg_name = "f"
      let help = "Displays the final abstract state in Dot File <f>"
    end)

module Warn = struct
  let no_return_stmt = register_warn_category "no-return"
  let undefined_function = register_warn_category "undefined:fn"
  let unsupported_address = register_warn_category "unsupported:addr"
  let unsupported_asm = register_warn_category "unsupported:asm"
  let unsupported_function = register_warn_category "unsupported:fn"
  let unsafe_cast = register_warn_category "unsafe-cast"
end

module DebugKeys = struct
  let lvals = register_category "lvals"
end
