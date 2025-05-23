(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(* -------------------------------------------------------------------------- *)
(* --- Plugin Registration                                                --- *)
(* -------------------------------------------------------------------------- *)

include Plugin.Register
    (struct
      let name = "Region Analysis"
      let help = "Memory Region Analysis (experimental)"
      let shortname = "region"
    end)

module Enabled = False
    (struct
      let option_name = "-region"
      let help = "Enable Region Analysis"
    end)
