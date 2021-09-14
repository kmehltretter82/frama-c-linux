(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2020                                               *)
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

let () = Plugin.is_share_visible ()
module P = Plugin.Register
    (struct
      let name = "E-ACSL"
      let shortname = "e-acsl"
      let help = "Executable ANSI/ISO C Specification Language --- runtime \
                  assertion checker generator"
    end)
include P

module Run =
  False
    (struct
      let option_name = "-e-acsl"
      let help = "generate a new project where E-ACSL annotations are \
                  translated to executable C code"
    end)

module Project_name =
  String
    (struct
      let option_name = "-e-acsl-project"
      let help = "the name of the generated project is <prj> \
                  (default to \"e-acsl\")"
      let default = "e-acsl"
      let arg_name = "prj"
    end)

module Valid =
  False
    (struct
      let option_name = "-e-acsl-valid"
      let help = "translate annotation which have been proven valid"
    end)

module Gmp_only =
  False
    (struct
      let option_name = "-e-acsl-gmp-only"
      let help = "always use GMP integers instead of C integral types"
    end)

module Temporal_validity =
  False
    (struct
      let option_name = "-e-acsl-temporal-validity"
      let help = "enable temporal analysis in valid annotations"
    end)

module Validate_format_strings =
  False
    (struct
      let option_name = "-e-acsl-validate-format-strings"
      let help = "enable runtime validation of stdio.h format functions"
    end)

module Replace_libc_functions =
  False
    (struct
      let option_name = "-e-acsl-replace-libc-functions"
      let help = "replace some libc functions (such as strcpy) with built-in\
                  RTL alternatives"
    end)

module Full_mtracking =
  False
    (struct
      let option_name = "-e-acsl-full-mtracking"
      let help = "maximal memory-related instrumentation"
    end)
let () = Full_mtracking.add_aliases ~deprecated:true [ "-e-acsl-full-mmodel" ]

module Builtins =
  String_set
    (struct
      let option_name = "-e-acsl-builtins"
      let arg_name = ""
      let help = "C functions which can be used in the E-ACSL specifications"
    end)

let () = Parameter_customize.is_invisible ()
module Assert_print_data =
  False
    (struct
      let option_name = "-e-acsl-assert-print-data"
      let help = "print data contributing to the failed assertion along with \
                  the runtime error message"
    end)

module Functions =
  Kernel_function_set
    (struct
      let option_name = "-e-acsl-functions"
      let arg_name = "f1, ..., fn"
      let help = "only annotations in functions f1, ..., fn are checked at \
                  runtime"
    end)

module Instrument =
  Kernel_function_set
    (struct
      let option_name = "-e-acsl-instrument"
      let arg_name = "f1, ..., fn"
      let help = "only instrument functions f1, ..., fn. \
                  Be aware that runtime verdicts may become partial."
    end)


let () = Parameter_customize.set_group help
module Version =
  False
    (struct
      let option_name = "-e-acsl-version"
      let help = "version of plug-in E-ACSL"
    end)

let version () =
  if Version.get () then begin
    Log.print_on_output
      (fun fmt ->
         Format.fprintf
           fmt
           "Version of plug-in E-ACSL: %s@?"
           Local_config.version);
    raise Cmdline.Exit
  end
let () = Cmdline.run_after_configuring_stage version

let parameter_states =
  [ Valid.self;
    Gmp_only.self;
    Full_mtracking.self;
    Builtins.self;
    Temporal_validity.self;
    Validate_format_strings.self;
    Functions.self;
    Instrument.self ]

let emitter =
  Emitter.create
    "E_ACSL"
    [ Emitter.Code_annot; Emitter.Funspec ]
    ~correctness:[ Functions.parameter;
                   Instrument.parameter;
                   Validate_format_strings.parameter;
                   Temporal_validity.parameter ]
    ~tuning:[ Gmp_only.parameter;
              Valid.parameter;
              Replace_libc_functions.parameter;
              Full_mtracking.parameter ]

let must_visit () = Run.get ()

let dkey_analysis = register_category "analysis"
let dkey_prepare = register_category "preparation"
let dkey_translation = register_category "translation"
let dkey_typing = register_category "typing"

(*
Local Variables:
compile-command: "make -C ../../../.."
End:
*)
