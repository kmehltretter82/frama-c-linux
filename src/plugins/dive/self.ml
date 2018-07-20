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

module Targets = String_multiple_map
    (struct
      include Datatype.Integer
      type key = string
      let of_string ~key:_ ~prev:_ arg =
        try
          Extlib.opt_map Integer.of_string arg
        with Failure _ ->
          raise (Cannot_build "expecting an integer")
      let to_string ~key:_ = Extlib.opt_map Integer.to_string
    end)
    (struct
      let option_name = "-iig"
      let help = "Defines the lvalues for which the dependency graph must be \
                  generated"
      let default = Datatype.String.Map.empty
      let arg_name = "lval:sid"
    end)

module FoldedBases = String_set
    (struct
      let option_name = "-iig-fold"
      let help = "Defines the name of the composite variables which should be \
                  considered as a single location"
      let arg_name = "lval:sid"
    end)
