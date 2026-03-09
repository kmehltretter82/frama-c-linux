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

module Logic = False
    (struct
      let option_name = "-region-logic"
      let help = "Also generate guards for logical statements"
    end)

let () = Parameter_customize.set_negative_option_name "-region-check"
let () = Parameter_customize.set_negative_option_help "Generate ACSL 'check' annotations"
module Assert = False
    (struct
      let option_name = "-region-assert"
      let help = "Generate ACSL 'assert' annotations instead of checks"
    end)

module Rte = False
    (struct
      let option_name = "-region-rte"
      let help = "Generate ACSL annotations for all functions"
    end)
