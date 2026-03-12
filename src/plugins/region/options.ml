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

module Analyze = Action
    (struct
      let option_name = "-region"
      let help = "Analyze Regions for all functions"
    end)

module Annotate = Action
    (struct
      let option_name = "-region-annotate"
      let help = "Generate Region and RTE checks"
    end)

let () = Parameter_customize.set_negative_option_name "-region-check"
let () = Parameter_customize.set_negative_option_help "Generate ACSL 'check' annotations"
module Assert = False
    (struct
      let option_name = "-region-assert"
      let help = "Generate ACSL 'assert' annotations instead of checks"
    end)

module Logic = False
    (struct
      let option_name = "-region-logic"
      let help = "Also generate guards for logical statements"
    end)
