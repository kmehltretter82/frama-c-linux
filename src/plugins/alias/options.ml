(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C plug-in 'Alias' (alias).             *)
(*                                                                        *)
(*  Copyright (C) 2022-2023                                               *)
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
(*  for more details (enclosed in the file LICENSE)                       *)
(*                                                                        *)
(**************************************************************************)

(* -------------------------------------------------------------------------- *)
(* --- Plugin Registration                                                --- *)
(* -------------------------------------------------------------------------- *)

include Plugin.Register
    (struct
      let name = "Alias"
      let help = "Light May-Alias Analyzer"
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
