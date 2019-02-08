(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C plug-in `Dive'.                      *)
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
      let name = "dive"
      let shortname = "dive"
      let help = "An interactive imprecision graph generator."
    end)

module DepthLimit = Int
    (struct
      let default = 5
      let option_name = "-dive-depth-limit"
      let help = "Build dependencies up to a depth of N."
      let arg_name = "N"
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
      let option_name = "-dive"
      let help = "Defines the lvalues for which the dependency graph must be \
                  generated."
      let default = Datatype.String.Map.empty
      let arg_name = "lval:sid"
    end)

module UnfoldedBases = String_set
    (struct
      let option_name = "-dive-unfold"
      let help = "Defines the names of the composite variables which should be \
                  unfolded into each individual cell."
      let arg_name = "lval:sid"
    end)

module HiddenBases = String_set
    (struct
      let option_name = "-dive-hide"
      let help = "Defines the names of the variables which must not be \
                  displayed in the graph. The dependencies for these bases \
                  are not computed either."
      let arg_name = "lval:sid"
    end)
