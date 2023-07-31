(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2025                                               *)
(*    CEA (Commissariat à l'énergie atomique et aux énergies              *)
(*         alternatives)                                                  *)
(*                                                                        *)
(*  All rights reserved.                                                  *)
(*  Contact CEA LIST for licensing.                                       *)
(*                                                                        *)
(**************************************************************************)

let () = Plugin.is_share_visible ()
module MThread = Plugin.Register (
  struct
    let name = "mthread"
    let shortname = "mt"
    let help = "tools for multi-threaded programs (experimental)"
  end)
;;
(* Including this module directly is a bad idea, as this hides the
   "String" module of the standard library... *)

(* Reexport useful values *)
include (MThread: Log.Messages)

let debug_level () = MThread.Debug.get ()

open MThread

let grp_models = add_group "Extraction of models"
let grp_debug = add_group "Debug"
let grp_cfg = add_group "Multithreaded control-flow-graph"
(*let grp_misc = add_group "Misc"*)
let grp_analysis = add_group "Analysis"

module Enabled =
  False (struct
    let option_name = "-mthread"
    let help = "enable analysis of multi-threaded programs through the Mthread plugin"
  end)
;;

let () = Parameter_customize.set_group grp_debug
module KeepProjects =
  String (struct
    let option_name = "-mt-keep-analyses"
    let help = "keep a copy of the analyses done for each thread"
    let default = "last"
    let arg_name = "all|last|none"
  end)
;;
let () = KeepProjects.set_possible_values ["all"; "last"; "none"]

let () = Parameter_customize.set_group grp_debug
let () = Parameter_customize.set_negative_option_name "-mt-projects-together"
module ToDisk =
  False (struct
    let option_name = "-mt-projects-on-disk"
    let help = "Save the copies of the analyses in a separate file, instead of all together"
  end)
;;

let () = Parameter_customize.set_group grp_debug
let () = Parameter_customize.set_negative_option_name "-mt-consider-null"
module IgnoreNull =
  False (struct
    let option_name = "-mt-ignore-null"
    let help = "Ignore shared accesses to numeric memory (NULL base)"
  end)
;;


let () = Parameter_customize.set_group grp_debug
module ToDiskPrefix =
  String
    (struct
      let option_name = "-mt-projects-on-disk-prefix"
      let arg_name = "prefix"
      let default = "th"
      let help = "Prepend <prefix> to the project's filename saved by -mt-projects-on-disk (defaults to th)"
    end)



let () = Parameter_customize.set_group grp_analysis
module WriteWriteRaces =
  False (struct
    let option_name = "-mt-write-races"
    let help = "Display memory on which there is a write-only race condition"
  end)

let () = Parameter_customize.set_group grp_analysis
module DumpSharedVarsValues =
  Int (struct
    let default = 0
    let option_name = "-mt-shared-values"
    let help = "Show what threads read and write in shared memory at the end of each iteration\n\
                0: values not shown\n\
                1: values shown\n\
                2: values shown with the stack at which the operation occurs"
    let arg_name = "level"
  end)
let () = DumpSharedVarsValues.set_range ~min:0 ~max:2

let () = Parameter_customize.set_group grp_analysis
module CheckProtections =
  False (struct
    let help = "more precise inference of which mutexes protect shared memory"
    let option_name = "-mt-shared-accesses-synchronization"
  end)

let () = Parameter_customize.set_group messages
module ModerateWarnings =
  True (struct
    let option_name = "-mt-moderate-warnings"
    let help = "Show semi-important warnings during analysis."
  end)

let () = Parameter_customize.set_group messages
module NiceOffsets  =
  True (struct
    let option_name = "-mt-nice-offsets"
    let help = "Try to display nice offsets for objects names"
  end)

let () = Parameter_customize.set_group messages
module PrintCallstacks  =
  False (struct
    let option_name = "-mt-print-callstacks"
    let help = "Print the callstacks at which concurrent events occur"
  end)

let () = Parameter_customize.set_group grp_debug
module ShowSid =
  False (struct
    let option_name = "-mt-show-sids"
    let help = "Show statement ids when printing line numbers"
  end)
;;

let () = Parameter_customize.set_group grp_debug
module ShowTime =
  False (struct
    let option_name = "-mt-time"
    let help = "Show time taken by thread computation"
  end)
;;

let () = Parameter_customize.set_group grp_debug
module SkipThreads =
  String_set
    (struct
      let option_name = "-mt-skip-threads"
      let arg_name = "th1,...,thn"
      let help = "do not execute the specified threads"
    end)
;;

let () = Parameter_customize.set_group grp_debug
module OnlyThreads =
  String_set
    (struct
      let option_name = "-mt-only-threads"
      let arg_name = "th1,...,thn"
      let help = "only execute the specified threads"
    end)
;;



let () = Parameter_customize.set_group grp_debug
module StopAfter =
  Int (struct
    let default = max_int
    let option_name = "-mt-stop-after"
    let help = "Only perform at most i iterations"
    let arg_name = "i"
  end)
;;

let () = Parameter_customize.set_group grp_debug
module KeepDotFiles =
  False
    (struct
      let option_name = "-mt-keep-dot"
      let help = "keep dot files generated by the html output"
    end)
;;


let () = Parameter_customize.set_group grp_models
module ExtractModels =
  String_set
    (struct
      let option_name = "-mt-extract"
      let arg_name = "[html]"
      let help = "extraction of models"
    end)
;;

let () = Parameter_customize.set_group grp_cfg
module FullCfg =
  False (struct
    let option_name = "-mt-full-cfg"
    let help = "Do not simplify cfg and show all statements (can be costly)"
  end)
;;

let () = Parameter_customize.set_group grp_cfg
module KeepWhiteNodes =
  False (struct
    let option_name = "-mt-non-shared-accesses"
    let help = "Keep accesses to false shared variables in the cfg"
  end)
;;

let () = Parameter_customize.set_group grp_cfg
module KeepGreenNodes =
  True (struct
    let option_name = "-mt-non-concurrent-accesses"
    let help = "Keep non-concurrent accesses to shared variables in the cfg"
  end)
;;

let () = Parameter_customize.set_group grp_cfg
module ShowReturnEdges =
  True (struct
    let option_name = "-mt-return-edges"
    let help = "Show link between a call an a return instruction as a dotted line"
  end)
;;

let () = Parameter_customize.set_group grp_cfg
module PopTopFunctionForCallbacks =
  False (struct
    let option_name = "-mt-inline-callbacks"
    let help = "Do not show the names of concurrent primitives, only their effect"
  end)
;;

let () = Parameter_customize.set_group grp_cfg
module CompactFunctions =
  String_set
    (struct
      let option_name = "-mt-compact"
      let arg_name = "f"
      let help = "do not show the body of the given functions"
    end)
;;
