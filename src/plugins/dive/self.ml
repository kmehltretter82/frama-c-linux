(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C plug-in `IIG'.                       *)
(*                                                                        *)
(*  Copyright (C) 2018                                                    *)
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

include Plugin.Register
  (struct
     let name = "iig"
     let shortname = "iig"
     let help = "An interactive imprecision graph generator."
     end)

module Run = False
  (struct
    let option_name = "-iig"
    let help = "Generates an interactive imprecision graph from Eva results."
   end)

module Lval = String
  (struct
    let option_name = "-iig-lval"
    let help = "The lval for which the dependency graph must be generated"
    let default = ""
    let arg_name = "lval"
  end)

module StatementId = Int
  (struct
    let option_name = "-iig-sid"
    let help = "The statement id in which the lval must be evaluated"
    let default = -1
    let arg_name = "sid"
  end)
