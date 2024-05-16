(**************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2024                                               *)
(*    CEA (Commissariat a l'energie atomique et aux energies              *)
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
let () = Plugin.is_session_visible ()
include Plugin.Register
    (struct
      let name = "WP"
      let shortname = "wp"
      let help = "Proof by Weakest Precondition Calculus"
    end)

(* localize all warnings inside WP *)

let warning ?wkey ?current = match current with
  | None -> warning ?wkey ~current:true
  | Some b -> warning ?wkey ~current:b

let wkey_hyp = register_warn_category "hypothesis"

let hypothesis ?current ?source ?emitwith ?echo ?once ?append text =
  warning ~wkey:wkey_hyp ?current ?source ?emitwith ?echo ?once ?append text

let resetdemon = ref []
let on_reset f = resetdemon := f :: !resetdemon
let reset () = List.iter (fun f -> f ()) !resetdemon
let has_dkey (k:category) = is_debug_key_enabled k

let server = ref false
let () = Server.Main.once (fun () -> server := true)
let is_interactive () = Fc_config.is_gui || !server

(* ------------------------------------------------------------------------ *)
(* ---  WP Generation                                                   --- *)
(* ------------------------------------------------------------------------ *)

let wp_generation = add_group "Goal Generator"

let () = Parameter_customize.set_group wp_generation
let () = Parameter_customize.do_not_save ()
module WP =
  Action(struct
    let option_name = "-wp"
    let help = "Generate proof obligations for all (selected) properties."
  end)
let () = on_reset WP.clear

let () = Parameter_customize.set_group wp_generation
module Dump =
  Action(struct
    let option_name = "-wp-dump"
    let help = "Dump WP calculus graph."
  end)
let () = on_reset Dump.clear

let () = Parameter_customize.set_group wp_generation
let () = Parameter_customize.do_not_save ()
module Functions =
  Kernel_function_set
    (struct
      let option_name = "-wp-fct"
      let arg_name = "f,..."
      let help = "Select properties of given functions (defaults to all functions)."
    end)
let () = on_reset Functions.clear

let () = Parameter_customize.set_group wp_generation
let () = Parameter_customize.do_not_save ()
module SkipFunctions =
  Kernel_function_set
    (struct
      let option_name = "-wp-skip-fct"
      let arg_name = "f,..."
      let help = "Skip the specified functions (defaults to none)."
    end)
let () = on_reset SkipFunctions.clear

let () = Parameter_customize.set_group wp_generation
let () = Parameter_customize.do_not_save ()
module Behaviors =
  String_list
    (struct
      let option_name = "-wp-bhv"
      let arg_name = "b,..."
      let help = "Select only properties belonging to listed behaviors (the name \"default!\" can be used to select the default anonymous behavior) of the selected functions (defaults to all behaviors)."
    end)
let () = on_reset Behaviors.clear

let () = Parameter_customize.set_group wp_generation
let () = Parameter_customize.do_not_save ()
let () = Parameter_customize.no_category ()
module Properties =
  String_list
    (struct
      let option_name = "-wp-prop"
      let arg_name = "p,..."
      let help =
        "Select properties based names and category.\n\
         Use +name or +category to select properties and -name or -category \
         to remove them from the selection. The '+' sign can be omitted.\n\
         Categories are: @lemma, @requires, @assigns, @ensures, @exits, \
         @assert, @invariant, @variant, @breaks, @continues, @returns, \
         @complete_behaviors, @disjoint_behaviors, @terminates, \
         @decreases and @check (which includes all check clauses)."
    end)
let () = on_reset Properties.clear

let () = Parameter_customize.set_group wp_generation
module StatusAll =
  False(struct
    let option_name = "-wp-status-all"
    let help = "Select properties with any status."
  end)

let () = Parameter_customize.set_group wp_generation
module StatusTrue =
  False(struct
    let option_name = "-wp-status-valid"
    let help = "Select properties with status 'Valid'."
  end)

let () = Parameter_customize.set_group wp_generation
module StatusFalse =
  False(struct
    let option_name = "-wp-status-invalid"
    let help = "Select properties with status 'Invalid'."
  end)

let () = Parameter_customize.set_group wp_generation
module StatusMaybe =
  True(struct
    let option_name = "-wp-status-maybe"
    let help = "Select properties with status 'Maybe'."
  end)

(* ------------------------------------------------------------------------ *)
(* --- Selected Functions                                               --- *)
(* ------------------------------------------------------------------------ *)

module Fct = Cil_datatype.Kf.Set

type functions =
  | Fct_none
  | Fct_all
  | Fct_skip of Fct.t
  | Fct_list of Fct.t

let iter_fct phi = function
  | Fct_none -> ()
  | Fct_all -> Globals.Functions.iter phi
  | Fct_skip fs ->
    Globals.Functions.iter
      (fun kf -> if not (Fct.mem kf fs) then phi kf)
  | Fct_list fs -> Fct.iter phi fs

let get_kfs () =
  if Functions.is_empty() then
    if SkipFunctions.is_empty () then Fct_all
    else Fct_skip (SkipFunctions.get())
  else
    Fct_list (Fct.diff (Functions.get()) (SkipFunctions.get()))

let get_fct () =
  if WP.get () || not (Functions.is_empty()) ||
     not (Behaviors.is_empty()) || not (Properties.is_empty())
  then get_kfs ()
  else Fct_none

let iter_kf f = iter_fct f (get_fct ())

(* ------------------------------------------------------------------------ *)
(* ---  Memory Models                                                   --- *)
(* ------------------------------------------------------------------------ *)

let wp_model = add_group "Model Selection"

let () = Parameter_customize.set_group wp_model
module Model =
  String_list
    (struct
      let option_name = "-wp-model"
      let arg_name = "model+..."
      let help = "Memory model selection. Available selectors:\n\
                  * 'Hoare' logic variables only\n\
                  * 'Typed' typed pointers only\n\
                  * '+nocast' no pointer cast\n\
                  * '+cast' unsafe pointer casts\n\
                  * '+raw' no logic variable\n\
                  * '+ref' by-reference-style pointers detection\n\
                  * '+nat/+int' natural / machine-integers arithmetics\n\
                  * '+real/+float' real / IEEE floating point arithmetics\n\
                  * 'Eva' (experimental) based on the results from Eva plugin"
    end)

let () = Parameter_customize.set_group wp_model
module ByValue =
  String_set
    (struct
      let option_name = "-wp-unalias-vars"
      let arg_name = "var,..."
      let help = "Consider variable names non-aliased."
    end)

let () = Parameter_customize.set_group wp_model
module ByRef =
  String_set
    (struct
      let option_name = "-wp-ref-vars"
      let arg_name = "var,..."
      let help = "Consider variable names by reference."
    end)

let () = Parameter_customize.set_group wp_model
module InHeap =
  String_set
    (struct
      let option_name = "-wp-alias-vars"
      let arg_name = "var,..."
      let help = "Consider variable names aliased."
    end)

let () = Parameter_customize.set_group wp_model
module AliasInit =
  False(struct
    let option_name = "-wp-alias-init"
    let help = "Use initializers for aliasing propagation."
  end)

let () = Parameter_customize.set_group wp_model
module InCtxt =
  String_set
    (struct
      let option_name = "-wp-context-vars"
      let arg_name = "var,..."
      let help = "Consider variable names in isolated context."
    end)

let () = Parameter_customize.set_group wp_model
module ExternArrays =
  False(struct
    let option_name = "-wp-extern-arrays"
    let help = "Put some default size for extern arrays."
  end)

let () = Parameter_customize.set_group wp_model
module WeakIntModel =
  False(struct
    let option_name = "-wp-weak-int-model"
    let help = "Suppress integral type side conditions within lemmas\n\
                (possibly unsound)"
  end)

let () = Parameter_customize.set_group wp_model
module Literals =
  False(struct
    let option_name = "-wp-literals"
    let help = "Export content of string literals."
  end)

let () = Parameter_customize.set_group wp_model
module Volatile =
  True(struct
    let option_name = "-wp-volatile"
    let help = "Sound modeling of volatile access.\n\
                Use -wp-no-volatile to ignore volatile attributes."
  end)

(* -------------------------------------------------------------------------- *)
(* --- Region Model                                                       --- *)
(* -------------------------------------------------------------------------- *)

let wp_region = add_group "Region Analysis"

let () = Parameter_customize.set_group wp_region
let () = Parameter_customize.do_not_save ()
module Region =
  False
    (struct
      let option_name = "-wp-region"
      let help = "Perform Region Analysis (experimental)"
    end)

let () = Parameter_customize.set_group wp_region
let () = Parameter_customize.do_not_save ()
module Region_fixpoint =
  True
    (struct
      let option_name = "-wp-region-fixpoint"
      let help = "Compute region aliasing fixpoint"
    end)

let () = Parameter_customize.set_group wp_region
let () = Parameter_customize.do_not_save ()
module Region_cluster =
  True
    (struct
      let option_name = "-wp-region-cluster"
      let help = "Compute region clustering fixpoint"
    end)

let () = Parameter_customize.set_group wp_region
let () = Parameter_customize.do_not_save ()
module Region_inline =
  True
    (struct
      let option_name = "-wp-region-inline"
      let help = "Inline aliased sub-clusters"
    end)

let () = Parameter_customize.set_group wp_region
let () = Parameter_customize.do_not_save ()
module Region_rw =
  True
    (struct
      let option_name = "-wp-region-rw"
      let help = "Written region are considered read-write by default"
    end)

let () = Parameter_customize.set_group wp_region
let () = Parameter_customize.do_not_save ()
module Region_pack =
  True
    (struct
      let option_name = "-wp-region-pack"
      let help = "Pack clusters by default"
    end)

let () = Parameter_customize.set_group wp_region
let () = Parameter_customize.do_not_save ()
module Region_flat =
  False
    (struct
      let option_name = "-wp-region-flat"
      let help = "Flatten arrays by default"
    end)

let () = Parameter_customize.set_group wp_region
module Region_annot =
  False
    (struct
      let option_name = "-region-annot"
      let help = "Register '@region' ACSL Annotations (auto with -wp-region)"
    end)

let () = Parameter_customize.set_group wp_region
let () = Parameter_customize.is_invisible ()
module Region_output_dot =
  Filepath
    (struct
      let option_name = "-wp-region-output-dot"
      let arg_name = "output.dot"
      let file_kind = "DOT"
      let existence = Fc_Filepath.Indifferent
      let help = "Outputs the region graph in DOT format to the specified file."
    end)

(* ------------------------------------------------------------------------ *)
(* ---  WP Strategy                                                     --- *)
(* ------------------------------------------------------------------------ *)

let wp_strategy = add_group "Computation Strategies"

let () = Parameter_customize.set_group wp_strategy
module Init =
  True(struct
    let option_name = "-wp-init-const"
    let help = "Use initializers for global const variables."
  end)

let () = Parameter_customize.set_group wp_strategy
module CalleePreCond =
  True(struct
    let option_name = "-wp-callee-precond"
    let help = "Use pre-conditions of callee."
  end)

let () = Parameter_customize.set_group wp_strategy
module RTE =
  False(struct
    let option_name = "-wp-rte"
    let help = "Generate RTE guards before WP."
  end)

let () = Parameter_customize.set_group wp_strategy
module SmokeTests =
  False(struct
    let option_name = "-wp-smoke-tests"
    let help = "Smoke-tests : look for inconsistent contracts (best effort)"
  end)

let () = Parameter_customize.set_group wp_strategy
module SmokeDeadassumes =
  True(struct
    let option_name = "-wp-smoke-dead-assumes"
    let help = "When generating smoke tests, look for dead assumes"
  end)

let () = Parameter_customize.set_group wp_strategy
module SmokeDeadcode =
  True(struct
    let option_name = "-wp-smoke-dead-code"
    let help = "When generating smoke tests, look for unreachable code"
  end)

let () = Parameter_customize.set_group wp_strategy
module SmokeDeadcall =
  True(struct
    let option_name = "-wp-smoke-dead-call"
    let help = "When generating smoke tests, look for non-terminating calls"
  end)

let () = Parameter_customize.set_group wp_strategy
module SmokeDeadlocalinit =
  False(struct
    let option_name = "-wp-smoke-dead-local-init"
    let help = "When generating smoke tests, look for dead local variables \
                initialization"
  end)

let () = Parameter_customize.set_group wp_strategy
module SmokeDeadloop =
  True(struct
    let option_name = "-wp-smoke-dead-loop"
    let help = "When generating smoke tests, look for inconsistent loop invariants"
  end)

let () = Parameter_customize.set_group wp_strategy
module SplitBranch =
  False(struct
    let option_name = "-wp-split"
    let help = "Split if-then-else into sub-goals (see also -wp-max-split)"
  end)

let () = Parameter_customize.set_group wp_strategy
module SplitSwitch =
  True(struct
    let option_name = "-wp-split-switch"
    let help = "Split switch-cases into sub-goals (see also -wp-max-split)."
  end)

let () = Parameter_customize.set_group wp_strategy
module SplitConj =
  False(struct
    let option_name = "-wp-split-conj"
    let help = "Split conjunctive goals into sub-goals"
  end)

let () = Parameter_customize.set_group wp_strategy
module SplitCNF =
  Int(struct
    let option_name = "-wp-split-cnf"
    let default = 0
    let arg_name = "N"
    let help =
      "Apply CNF transformation on goals at depth N (default 0, -1 unlimited)"
  end)

let () = Parameter_customize.set_group wp_strategy
module SplitMax =
  Int(struct
    let option_name = "-wp-max-split"
    let default = 1000
    let arg_name = "n"
    let help = "Set maximum number of splitted sub-goals (default 1000)"
  end)

let () = Parameter_customize.set_group wp_strategy
module UnfoldAssigns =
  Int(struct
    let option_name = "-wp-unfold-assigns"
    let default = 0
    let arg_name = "n"
    let help = "Unfold up to <n> levels of aggregates and arrays in assigns.\n\
                Value -1 means unlimited depth (default 0)"
  end)

let () = Parameter_customize.set_group wp_strategy
let () = Parameter_customize.is_invisible ()
module DynCall =
  True(struct
    let option_name = "-wp-dynamic"
    let help = "Handle dynamic calls with specific annotations."
  end)

(* NOT use DynCall.add_set_hook: it won't work for the positive version of
   the option, as the default is already true. *)
let () =
  Cmdline.run_after_configuring_stage
    (fun () ->
       if DynCall.is_set () then
         warning ~current:false
           "Option -wp-dynamic is obsolete and will be removed \
            at some point in the future. @@calls annotations are now handled \
            directly in the kernel")

let () = Parameter_customize.set_group wp_strategy
module PrecondWeakening =
  False(struct
    let option_name = "-wp-precond-weakening"
    let help = "Discard pre-conditions of side behaviours (sound but incomplete optimisation)."
  end)

let () = Parameter_customize.set_group wp_strategy
module TerminatesVariantHyp =
  False(struct
    let option_name = "-wp-variant-with-terminates"
    let help = "Prove loop variant under the termination hypothesis."
  end)

(* ------------------------------------------------------------------------ *)
(* ---  Qed Simplifications                                             --- *)
(* ------------------------------------------------------------------------ *)

let wp_simplifier = add_group "Qed Simplifications"

let () = Parameter_customize.set_group wp_simplifier
module Simpl =
  True(struct
    let option_name = "-wp-simpl"
    let help = "Enable Qed Simplifications."
  end)

let () = Parameter_customize.set_group wp_simplifier
module Let =
  True(struct
    let option_name = "-wp-let"
    let help = "Use variable elimination."
  end)

let () = Parameter_customize.set_group wp_simplifier
module Core =
  True(struct
    let option_name = "-wp-core"
    let help = "Lift core facts through branches."
  end)

let () = Parameter_customize.set_group wp_simplifier
module Prune =
  True(struct
    let option_name = "-wp-pruning"
    let help = "Prune trivial branches."
  end)

let () = Parameter_customize.set_group wp_simplifier
module FilterInit =
  True(struct
    let option_name = "-wp-filter-init"
    let help = "Use aggressive filtering of initialization hypotheses."
  end)

let () = Parameter_customize.set_group wp_simplifier
module Clean =
  True(struct
    let option_name = "-wp-clean"
    let help = "Use a simple cleaning in case of -wp-no-let."
  end)

let () = Parameter_customize.set_group wp_simplifier
module Ground =
  True(struct
    let option_name = "-wp-ground"
    let help = "Use aggressive ground simplifications."
  end)

let () = Parameter_customize.set_group wp_simplifier
module Reduce =
  True(struct
    let option_name = "-wp-reduce"
    let help = "Reduce function equalities with precedence to constructors."
  end)

let () = Parameter_customize.set_group wp_simplifier
module ExtEqual =
  True(struct
    let option_name = "-wp-extensional"
    let help = "Use extensional equality on compounds (hypotheses only)."
  end)

let () = Parameter_customize.set_group wp_simplifier
module Filter =
  True(struct
    let option_name = "-wp-filter"
    let help = "Filter non-used variables and related hypotheses."
  end)

let () = Parameter_customize.set_group wp_simplifier
module Parasite =
  True(struct
    let option_name = "-wp-parasite"
    let help = "Use singleton-variable filtering."
  end)

let () = Parameter_customize.set_group wp_simplifier
module Prenex =
  False(struct
    let option_name = "-wp-prenex"
    let help = "Normalize nested foralls into prenex-form"
  end)

let () = Parameter_customize.set_group wp_simplifier
module SimplifyIsCint =
  True(struct
    let option_name = "-wp-simplify-is-cint"
    let help = "Remove redundant machine integer range hypothesis."
  end)

let () = Parameter_customize.set_group wp_simplifier
module SimplifyLandMask =
  True(struct
    let option_name = "-wp-simplify-land-mask"
    let help = "Tight logical masks on unsigned integers."
  end)

let () = Parameter_customize.set_group wp_simplifier
module SimplifyForall =
  False(struct
    let option_name = "-wp-simplify-forall"
    let help = "Remove machine integer ranges in quantifiers."
  end)

let () = Parameter_customize.set_group wp_simplifier
module SimplifyType =
  False(struct
    let option_name = "-wp-simplify-type"
    let help = "Remove all `Type` constraints."
  end)

let () = Parameter_customize.set_group wp_simplifier
module InitWithForall =
  True(struct
    let option_name = "-wp-init-summarize-array"
    let help = "Summarize contiguous initializers with quantifiers."
  end)

let () = Parameter_customize.set_group wp_simplifier
module BoundForallUnfolding =
  Int(struct
    let option_name = "-wp-bound-forall-unfolding"
    let help = "Instantiate up to <n> forall-integers hypotheses."
    let arg_name="n"
    let default = 1000
  end)

(* ------------------------------------------------------------------------ *)
(* ---  Prover Interface                                                --- *)
(* ------------------------------------------------------------------------ *)

let wp_prover = add_group "Prover Interface"

let () = Parameter_customize.set_group wp_prover
module Provers = String_list
    (struct
      let option_name = "-wp-prover"
      let arg_name = "dp,..."
      let help =
        "Submit proof obligations to prover(s):\n\
         - 'none' (no prover run)\n\
         - 'script' (replay all session scripts)\n\
         - 'tip' (replay or init scripts for failed goals)\n\
         - '<why3-prover>' (any Why-3 prover, see -wp-detect)\n\
        "
    end)

let () = Parameter_customize.set_group wp_prover
module Interactive = String
    (struct
      let option_name = "-wp-interactive"
      let arg_name = "mode"
      let default = "batch"
      let help =
        "WP mode for interactive Why-3 provers (eg: Coq):\n\
         - 'batch': check current proof (default)\n\
         - 'update': check updated proof\n\
         - 'edit': edit current proof\n\
         - 'fix': check current proof and edit if needed\n\
         - 'fixup': update proof, check it and edit if needed\n\
        "
    end)

let () = Parameter_customize.set_group wp_prover
module ScriptMode = String
    (struct
      let option_name = "-wp-script"
      let arg_name = "mode"
      let default = ""
      let help =
        "WP mode for managing scripts and proof strategies:\n\
         - 'batch': proof scripts are reused but not updated (default for script prover)\n\
         - 'update': proof scripts are reused and updated (default for tip prover)\n\
         - 'init': proof scripts are generated from scratch and saved\n\
         - 'dry': proof scripts are explored from scratch and not saved\n\
         See also option -wp-cache-env."
    end)

let () = Parameter_customize.set_group wp_prover
module StrategyEngine = True
    (struct
      let option_name = "-wp-strategy-engine"
      let help = "Activate @strategy and @proof annotations. (default: yes)"
    end)

let () = Parameter_customize.set_group wp_prover
module DefaultStrategies = String_list
    (struct
      let option_name = "-wp-strategy"
      let arg_name = "s,..."
      let help = "Use the specified strategies as default."
    end)

let () = Parameter_customize.set_group wp_prover
module RunAllProvers =
  False(struct
    let option_name = "-wp-run-all-provers"
    let help = "Run all specified provers on each goal not proved by Qed. \
                Do not stop when a prover succeeds. (default: no)"
  end)

let () = Parameter_customize.set_group wp_prover
module Cache = String
    (struct
      let option_name = "-wp-cache"
      let arg_name = "mode"
      let default = ""
      let help =
        "WP cache mode:\n\
         - 'none': no cache, run provers (default)\n\
         - 'update': use cache or run provers and update cache\n\
         - 'cleanup': update mode with garbage collection\n\
         - 'replay': update mode with no cache update\n\
         - 'rebuild': always run provers and update cache\n\
         - 'offline': use cache but never run provers\n\
         See also option -wp-cache-env."
    end)

let () = Parameter_customize.set_group wp_prover
module CacheDir = String
    (struct
      let option_name = "-wp-cache-dir"
      let arg_name = "dir"
      let default = ""
      let help =
        "Specify global cache directory (no cleanup mode).\n\
         By default, cache entries are stored in the WP session directory.\n\
         See also option -wp-cache-env."
    end)

let () = Parameter_customize.set_group wp_prover
module CacheEnv = False
    (struct
      let option_name = "-wp-cache-env"
      let help = "Gives environment variables precedence over command line\n\
                  for cache management:\n\
                  - FRAMAC_WP_SCRIPT overrides -wp-script\n\
                  - FRAMAC_WP_CACHE overrides -wp-cache\n\
                  - FRAMAC_WP_CACHEDIR overrides -wp-cache-dir\n\
                  Disabled by default."
    end)

let () = Parameter_customize.set_group wp_prover
module CachePrint = False
    (struct
      let option_name = "-wp-cache-print"
      let help = "Show cache directory"
    end)

let () = Parameter_customize.set_group wp_prover
module Generate = False
    (struct
      let option_name = "-wp-gen"
      let help = "Only generate prover files (default: no)."
    end)
let () = on_reset Generate.clear

let () = Parameter_customize.set_group wp_prover
module ScriptOnStdout = False
    (struct
      let option_name = "-wp-script-on-stdout"
      let help = "When enabled (default: no), display scripts on stdout \
                  instead of writing them on disk."
    end)

let () = Parameter_customize.set_group wp_prover
module PrepareScripts = Action
    (struct
      let option_name = "-wp-prepare-scripts"
      let help = "Initialize a script tracking directory in the session \
                  directory."
    end)

let () = Parameter_customize.set_group wp_prover
module FinalizeScripts = Action
    (struct
      let option_name = "-wp-finalize-scripts"
      let help = "Remove untracked scripts according to the tracking directory \
                  if it does exist (does not remove anything otherwise)."
    end)

let () = Parameter_customize.set_group wp_prover
module DryFinalizeScripts = False
    (struct
      let option_name = "-wp-dry-finalize-scripts"
      let help = "Scripts that might be removed by -wp-finalize-scripts are \
                  kept, a message is printed instead for each file. The marks \
                  directory is kept."
    end)

let () = Parameter_customize.set_group wp_prover
module Detect = Action
    (struct
      let option_name = "-wp-detect"
      let help = "List installed provers."
    end)
let () = on_reset Detect.clear

module Tactics = String_list
    (struct
      let option_name = "-wp-tactic"
      let arg_name = "id,..."
      let help = "Describe tactic. Use '?' for listing tactic names."
    end)
let () = on_reset Tactics.clear

let () = Parameter_customize.set_group wp_prover
let () = Parameter_customize.is_invisible ()
module Import =
  String_list
    (struct
      let option_name = "-wp-import"
      let arg_name = "thy,..."
      let help = "Import Why3 theories"
    end)

let () = Parameter_customize.set_group wp_prover
let () = Parameter_customize.is_invisible ()
module Library =
  Filepath_list
    (struct
      let option_name = "-wp-library"
      let arg_name = "dir,..."
      let file_kind = "Why3 load path"
      let existence = Fc_Filepath.Must_exist
      let help = "Load path for importing why3 theories"
    end)

let () = Parameter_customize.set_group wp_prover
module Drivers =
  Filepath_list
    (struct
      let option_name = "-wp-driver"
      let arg_name = "file,..."
      let file_kind = "WP library"
      let existence = Fc_Filepath.Must_exist
      let help = "Load drivers for linking to external libraries"
    end)

let () = Parameter_customize.set_group wp_prover
module Steps =
  Int(struct
    let option_name = "-wp-steps"
    let default = 0
    let arg_name = "n"
    let help = "Set number of steps for provers."
  end)

let () = Parameter_customize.set_group wp_prover
module Timeout =
  Int(struct
    let option_name = "-wp-timeout"
    let default = 2
    let arg_name = "t"
    let help =
      Printf.sprintf
        "Set the timeout (in seconds) for provers (default: %d)." default
  end)

let () = Parameter_customize.set_group wp_prover
module Memlimit =
  Int(struct
    let option_name = "-wp-memlimit"
    let default = 1000
    let arg_name = "m"
    let help =
      Printf.sprintf
        "Set the memory limit (in Mb) for provers (default: %d)." default
  end)

let () = Parameter_customize.set_group wp_prover
module FctTimeout =
  Kernel_function_map
    (struct
      include Datatype.Int
      type key = Cil_types.kernel_function
      let of_string ~key:_ ~prev:_ s =
        Option.map
          (fun s ->
             try int_of_string s
             with Failure _ ->
               raise (Cannot_build ("'" ^ s ^ "' is not an integer")))
          s
      let to_string ~key:_ = Option.map string_of_int
    end)
    (struct
      let option_name = "-wp-fct-timeout"
      let arg_name = "f1:t1,...,fn:tn"
      let help = "Customize the WP timeout (in secondes) for each specified \
                  function (t1 seconds for f1, t2 for f2, etc)."
      let default = Kernel_function.Map.empty
    end)

let () = Parameter_customize.set_group wp_prover
module SmokeTimeout =
  Int(struct
    let option_name = "-wp-smoke-timeout"
    let default = 2
    let arg_name = "n"
    let help =
      Printf.sprintf
        "Set the timeout (in seconds) for provers (default: %d)." default
  end)

let () = Parameter_customize.set_group wp_prover
module InteractiveTimeout =
  Int(struct
    let option_name = "-wp-interactive-timeout"
    let default = 30
    let arg_name = "time"
    let help =
      Printf.sprintf
        "Set the timeout (in seconds) for checking scripts\n\
         of interactive provers (default: %d)." default
  end)

let () = Parameter_customize.set_group wp_prover
module TimeExtra =
  Int(struct
    let option_name = "-wp-time-extra"
    let default = 1
    let arg_name = "n"
    let help =
      Printf.sprintf
        "Set extra-time (in seconds) for proof replay (default: %d)." default
  end)

let () = Parameter_customize.set_group wp_prover
module TimeMargin =
  String(struct
    let option_name = "-wp-time-margin"
    let default = "0.5"
    let arg_name = "n"
    let help =
      Printf.sprintf
        "Set margin-time (in seconds) for considering a proof automatic.\n\
         When using the 'tip' prover, scripts are created or cancelled\n\
         if the proof time is greater or lower than (timeout - margin).\n\
         (default: %s)." default
  end)

let () = Parameter_customize.set_group wp_prover
module Procs =
  Int(struct
    let option_name = "-wp-par"
    let arg_name = "p"
    let default = 4
    let help =
      Printf.sprintf
        "Number of parallel proof process (default: %d)" default
  end)

let () = Parameter_customize.set_group wp_prover
module ProofTrace =
  False
    (struct
      let option_name = "-wp-proof-trace"
      let help = "Keeps output of provers for valid POs (default: no)"
    end)

(* ------------------------------------------------------------------------ *)
(* ---  Prover Options                                                  --- *)
(* ------------------------------------------------------------------------ *)

let wp_prover_options = add_group "Prover Options"

let () = Parameter_customize.set_group wp_prover
module Auto = String_list
    (struct
      let option_name = "-wp-auto"
      let arg_name = "s"
      let help =
        "Activate auto-search with strategy <s>.\n\
         Use '-wp-auto <?>' for available strategies."
    end)

let () = Parameter_customize.set_group wp_prover
module AutoDepth = Int
    (struct
      let option_name = "-wp-auto-depth"
      let arg_name = "n"
      let default = 5
      let help =
        "Depth of auto-search (-wp-auto only, default 5).\n\
         Limits the number of nested level in strategies."
    end)

let () = Parameter_customize.set_group wp_prover
module AutoWidth = Int
    (struct
      let option_name = "-wp-auto-width"
      let arg_name = "n"
      let default = 10
      let help =
        "Width of auto-search (-wp-auto only, default 10).\n\
         Limits the number of pending goals in strategies."
    end)

let () = Parameter_customize.set_group wp_prover
module BackTrack = Int
    (struct
      let option_name = "-wp-auto-backtrack"
      let arg_name = "n"
      let default = 0
      let help =
        "Backtracking limit (-wp-auto only, de-activated by default).\n\
         Limits backtracking when applying strategies."
    end)

let () = Parameter_customize.set_group wp_prover_options
let () = Parameter_customize.no_category ()
module Why3Flags =
  String_list
    (struct
      let option_name = "-wp-why3-opt"
      let arg_name = "option,..."
      let help = "Additional options for Why3"
    end)

let () = Parameter_customize.set_group wp_prover_options
let () = Parameter_customize.no_category ()
module Why3ExtraConfig =
  String_list
    (struct
      let option_name = "-wp-why3-extra-config"
      let arg_name = "file,..."
      let help = "Additional config files for Why3"
    end)

(* ------------------------------------------------------------------------ *)
(* --- PO Management                                                    --- *)
(* ------------------------------------------------------------------------ *)

let wp_po = add_group "Proof Obligations"

let () = Parameter_customize.set_group wp_po
module TruncPropIdFileName =
  Int(struct
    let option_name = "-wp-filename-truncation"
    let default = 60
    let arg_name = "n"
    let help =
      "Truncate basename of proof obligation files after <n> characters.\n\
       Since numbers can be added as suffixes to make theses names unique,\n\
       filename lengths can be highter to <n>. No truncation is performed\n\
       when the value equals to zero (default: 60)."
  end)


let () = Parameter_customize.set_group wp_po
let () = Parameter_customize.do_not_save ()
module Print =
  Action(struct
    let option_name = "-wp-print"
    let help = "Pretty-prints proof obligations on standard output."
  end)
let () = on_reset Print.clear

let () = Parameter_customize.set_group wp_po
let () = Parameter_customize.do_not_save ()
module Status =
  Action(struct
    let option_name = "-wp-status"
    let help = "Pretty-prints pending proof obligations on standard output."
  end)
let () = on_reset Print.clear

let () = Parameter_customize.set_group wp_po
let () = Parameter_customize.do_not_save ()
module Report =
  String_list
    (struct
      let option_name = "-wp-report"
      let arg_name = "report,..."
      let help = "Report specification file(s)"
    end)

let () = Parameter_customize.set_group wp_po
let () = Parameter_customize.do_not_save ()
module ReportJson =
  Filepath(struct
    let option_name = "-wp-report-json"
    let arg_name ="file.json"
    let file_kind = "JSON report"
    let existence = Fc_Filepath.Indifferent
    let help = "Output proof results in JSON format."
  end)
let () = on_reset ReportJson.clear

let () = Parameter_customize.set_group wp_po
let () = Parameter_customize.do_not_save ()
module OldReportJson =
  String
    (struct
      let option_name = "-wp-deprecated-report-json"
      let arg_name = "file.json"
      let default = ""
      let help =
        "Output report in json format into given file.\n\
         If the file already exists, it is used for\n\
         stabilizing range of steps in other reports."
    end)

let () = Parameter_customize.set_group wp_po
let () = Parameter_customize.do_not_save ()
module ReportName =
  String(struct
    let option_name = "-wp-report-basename"
    let arg_name = "file"
    let default = "wp-report"
    let help = Printf.sprintf
        "Basename of generated reports (default %S)" default
  end)

let () = Parameter_customize.set_group wp_po
let () = Parameter_customize.do_not_save ()
module MemoryContext =
  True
    (struct
      let option_name = "-wp-warn-memory-model"
      let help = "Warn Against Memory Model Hypotheses"
    end)

let () = Parameter_customize.set_group wp_po
let () = Parameter_customize.do_not_save ()

module CheckMemoryContext =
  False
    (struct
      let option_name = "-wp-check-memory-model"
      let help = "Insert memory model hypotheses in function contracts and \
                  check them on call. (experimental)"
    end)

let () = Parameter_customize.set_group wp_po
module OutputDir =
  Filepath(struct
    let existence = Fc_Filepath.Indifferent
    let option_name = "-wp-out"
    let arg_name = "dir"
    let file_kind = "directory"
    let help = "Set working directory for generated files.\n\
                Defaults to some temporary directory."
  end)

module Probes =
  True
    (struct
      let option_name = "-wp-probes"
      let help = "Activate user-defines probes (@probe) (default: yes)"
    end)

module CounterExamples =
  False
    (struct
      let option_name = "-wp-counter-examples"
      let help = "Ask for counter examples when supported by provers"
    end)

(* -------------------------------------------------------------------------- *)
(* --- Output Dir                                                         --- *)
(* -------------------------------------------------------------------------- *)

let dkey = register_category "output"

let has_out () = not @@ Fc_Filepath.Normalized.is_empty (OutputDir.get ())

let make_output_dir dir =
  try
    if Extlib.mkdir ~parents:true dir 0o770 then
      debug ~dkey "Created output directory '%a'" Fc_Filepath.Normalized.pretty dir
  with Unix.Unix_error (err,_,_) ->
    let msg = Unix.error_message err in
    abort
      "System Error (%s)@\nCan not create output directory '%a'"
      msg Fc_Filepath.Normalized.pretty dir

(*[LC] Do not projectify this reference : it is common to all projects *)
let unique_tmp : Fc_Filepath.Normalized.t option ref = ref None
let make_tmp_dir () : Fc_Filepath.Normalized.t =
  match !unique_tmp with
  | None ->
    let tmp =
      try Extlib.temp_dir_cleanup_at_exit "wp"
      with Extlib.Temp_file_error s ->
        abort "Cannot create temporary file: %s" s
    in
    unique_tmp := Some tmp ;
    debug ~dkey "Created temporary directory '%a'" Fc_Filepath.Normalized.pretty tmp ;
    tmp
  | Some tmp -> tmp

let make_gui_dir () =
  try
    let home =
      try Sys.getenv "USERPROFILE" (*Win32*) with Not_found ->
      try Sys.getenv "HOME" (*Unix like*) with Not_found ->
        "." in
    let dir = Fc_Filepath.Normalized.of_string (home ^ "/" ^ ".frama-c-wp") in
    if Fc_Filepath.exists dir && Fc_Filepath.is_dir dir then
      Extlib.safe_remove_dir (dir:>string);
    make_output_dir dir ; dir
  with _ ->
    make_tmp_dir ()

(** call the construction of the directory only once *)
let base_output = ref None
let base_output () =
  match !base_output with
  | None ->
    let output =
      let dir = OutputDir.get () in
      if Fc_Filepath.Normalized.is_empty dir then
        if is_interactive ()
        then make_gui_dir ()
        else make_tmp_dir ()
      else
        ( make_output_dir dir ; dir ) in
    base_output := Some output;
    Fc_Filepath.add_symbolic_dir "WPOUT" output ; output
  | Some output -> output

let get_output () =
  let base = base_output () in
  let project = Project.current () in
  let name = Project.get_unique_name project in
  if name = "default" then base
  else
    let dir = Datatype.Filepath.concat base name in
    make_output_dir dir ; dir

let get_output_dir d =
  let base = get_output () in
  let path = Datatype.Filepath.concat base d in
  make_output_dir path ; path

(* -------------------------------------------------------------------------- *)
(* --- Session dir                                                        --- *)
(* -------------------------------------------------------------------------- *)

let default = Fc_Filepath.(Normalized.concat (pwd ()) "/.frama-c")

let has_session () =
  Session.is_set () ||
  ( Fc_Filepath.exists default && Fc_Filepath.is_dir default )

let get_session ~force () =
  if force then
    Session.get_dir "."
  else
  if Session.is_set () then
    Session.get ()
  else
    Session.get_dir "."

let get_session_dir ~force d =
  let base = get_session ~force () in
  let path = Datatype.Filepath.concat base d in
  if force then make_output_dir path ; path

(* -------------------------------------------------------------------------- *)
(* --- Print Generated                                                    --- *)
(* -------------------------------------------------------------------------- *)

let cat_print_generated = register_category "print-generated"

let has_print_generated () = has_dkey cat_print_generated

let print_generated ?header file =
  let header = match header with
    | None -> Fc_Filepath.Normalized.to_pretty_string file
    | Some head -> head in
  debug ~dkey:cat_print_generated "%S@\n%t@." header
    begin fun fmt ->
      if not (Fc_Filepath.exists file) then
        Format.pp_print_string fmt "<missing file>"
      else
        Command.read_lines file (fun s ->
            Format.pp_print_string fmt s;
            Format.pp_print_newline fmt ())
    end

(* -------------------------------------------------------------------------- *)
(* --- Debugging                                                          --- *)
(* -------------------------------------------------------------------------- *)

let protect e =
  if debug_atleast 1 then false else
    match e with
    | Sys.Break | Async.Cancel | Log.AbortError _ | Log.AbortFatal _ -> false
    | _ -> true

(* -------------------------------------------------------------------------- *)
