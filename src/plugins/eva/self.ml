(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2025                                               *)
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
      let name = "Eva"
      let shortname = "eva"
      let help =
        "automatically computes variation domains for the variables of the program"
    end)

(* Makes the help message of various categories mandatory. *)
let register_category ~help = register_category ~help
let register_warn_category ~help = register_warn_category ~help

let () =
  add_plugin_output_aliases ~visible:false ~deprecated:true [ "value" ; "val" ]

(* Do not add dependencies to Kernel parameters here, but at the top of
   Parameters. *)
let kernel_dependencies =
  [ Ast.self;
    Alarms.self;
    Annotations.code_annot_state; ]

let proxy = State_builder.Proxy.(create "eva" Forward kernel_dependencies)
let state = State_builder.Proxy.get proxy

(* Current state of the analysis *)
type computation_state = NotComputed | Computing | Computed | Aborted

module ComputationState =
struct
  let to_string = function
    | NotComputed -> "NotComputed"
    | Computing -> "Computing"
    | Computed -> "Computed"
    | Aborted -> "Aborted"

  module Prototype =
  struct
    include Datatype.Serializable_undefined
    type t = computation_state
    let name = "Eva.Analysis.ComputationState"
    let pretty fmt s = Format.pp_print_string fmt (to_string s)
    let reprs = [ NotComputed ; Computing ; Computed ; Aborted ]
    let dependencies = [ state ]
    let default () = NotComputed
  end

  module Datatype' = Datatype.Make (Prototype)
  include (State_builder.Ref (Datatype') (Prototype))
end

exception Abort

let is_computed () =
  match ComputationState.get () with
  | Computed | Aborted -> true
  | NotComputed | Computing -> false


(* ----- Debug categories --------------------------------------------------- *)

let dkey_initial_state =
  register_category "initial-state"
    ~help:"at the start of the analysis, \
           print the initial value of global variables"

let dkey_final_states =
  register_category "final-states"
    ~help:"at the end of the analysis, print final values inferred \
           at the return point of each analyzed function "

let dkey_summary =
  register_category "summary"
    ~help:"print a summary of the analysis at the end, including coverage \
           and alarm numbers"

let dkey_pointer_comparison =
  register_category "pointer-comparison"
    ~help:"messages about the evaluation of pointer comparisons"

let dkey_cvalue_domain =
  register_category "d-cvalue"
    ~help:"print states of the cvalue domain on some user directives"

let dkey_iterator =
  register_category "iterator"
    ~help:"debug messages about the fixpoint engine on the control-flow graph \
           of functions"

let dkey_widening =
  register_category "widening"
    ~help:"print a message at each point where the analysis applies a widening"

let dkey_partition =
  register_category "partition"
    ~help:"messages about states partitioning"

let dkey_split_return =
  register_category "split-return"
    ~help:"messages related to option -eva-split-return"

let dkey_precision_settings =
  register_category "precision-settings"
    ~help:"messages about the automatic configuration of the analysis by \
           option -eva-precision"

let dkey_callstacks =
  register_category "callstacks"
    ~help:"print the current callstack alongside some messages"

let dkey_callstack_hash =
  register_category "callstack-hash"
    ~help:"additionally print the current callstack hash in some messages"

let () =
  let activate dkey = add_debug_keys dkey in
  List.iter activate
    [dkey_initial_state; dkey_final_states; dkey_summary; dkey_cvalue_domain;
     dkey_partition; dkey_split_return; dkey_precision_settings]


(* ----- Warning categories ------------------------------------------------- *)

let wkey_alarm =
  register_warn_category "alarm"
    ~help:"warnings for each possible undefined behavior detected \
           by the analysis"

let wkey_locals_escaping =
  register_warn_category "locals-escaping"
    ~help:"a pointer p points to an out of scope local variable \
           (any use of p also generates an alarm)"

let _wkey_garbled_mix =
  register_warn_category "garbled-mix"
    ~help:"warnings about very imprecise values inferred for pointers, \
           named garbled mix"
    ~default:Log.Wfeedback

let wkey_garbled_mix_write =
  register_warn_category "garbled-mix:write"
    ~help:"the interpretation of an assignment creates a garbled mix"
    ~default:Log.Wfeedback

let wkey_garbled_mix_assigns =
  register_warn_category "garbled-mix:assigns"
    ~help:"the interpretation of a specification creates a garbled mix"
    ~default:Log.Wfeedback

let wkey_garbled_mix_summary =
  register_warn_category "garbled-mix:summary"
    ~help:"list the origins of garbled mix at the end of an analysis"
    ~default:Log.Wfeedback

let _wkey_builtins =
  register_warn_category "builtins"
    ~help:"warnings related to builtins used to interpret some libc functions"

let wkey_builtins_missing_spec =
  register_warn_category "builtins:missing-spec"
    ~help:"the ACSL specification on which a builtin soundness relies is missing"

let wkey_builtins_override =
  register_warn_category "builtins:override"
    ~help:"a builtin overrides a function definition, which is therefore \
           not analyzed"

let _wkey_libc =
  register_warn_category "libc"
    ~help:"warnings related to the interpretation of the standard C library"

let wkey_libc_unsupported_spec =
  register_warn_category "libc:unsupported-spec"
    ~help:"the ACSL specification of a libc function is not supported by Eva"

let _wkey_loop_unroll =
  register_warn_category "loop-unroll"
    ~help:"messages about automatic loop unrolling from option \
           -eva-auto-loop-unroll"
    ~default:Log.Wfeedback

let wkey_loop_unroll_auto =
  register_warn_category "loop-unroll:auto"
    ~help:"a loop is automatically unrolled by the analysis"

let wkey_loop_unroll_partial =
  register_warn_category "loop-unroll:partial"
    ~help:"a loop has been partially but not completely unrolled"

let wkey_missing_loop_unroll =
  register_warn_category "loop-unroll:missing"
    ~help:"a loop has no unroll annotation"
    ~default:Log.Winactive

let wkey_missing_loop_unroll_for =
  register_warn_category "loop-unroll:missing:for"
    ~help:"a for loop has no unroll annotation"
    ~default:Log.Winactive

let wkey_signed_overflow =
  register_warn_category "signed-overflow"
    ~help:"two's complement is used to interpret a signed overflow \
           (when signed overflow alarms are disabled)"

let _wkey_assigns =
  register_warn_category "assigns"
    ~help:"warnings related to the interpretation of assigns clauses \
           in ACSL specification"

let wkey_invalid_assigns =
  register_warn_category "assigns:invalid-location"
    ~help:"the memory location targeted by an assigns clause is invalid \
           in at least one analysis state"
    ~default:Log.Wfeedback

let wkey_missing_assigns =
  register_warn_category "assigns:missing"
    ~help:"assigns clauses are missing or incomplete from an ACSL \
           specification on which the analysis soundness relies"
    ~default:Log.Werror

let wkey_missing_assigns_result =
  register_warn_category "assigns:missing-result"
    ~help:"an assigns \\result clause is missing from an ACSL specification \
           on which the analysis soundness relies"

let wkey_experimental =
  register_warn_category "experimental"
    ~help:"an experimental feature of Eva is enabled"

let wkey_unknown_size =
  register_warn_category "unknown-size"
    ~help:"the analysis cannot compute the size of a variable, \
           which will thus be very imprecise"

let wkey_ensures_false =
  register_warn_category "ensures-false"
    ~help:"a post-condition evaluates to false; \
           there might be an error in the specification"

let wkey_watchpoint =
  register_warn_category "watchpoint"
    ~help:"undocumented"
    ~default:Log.Wfeedback

let wkey_recursion =
  register_warn_category "recursion"
    ~help:"a recursive call is analyzed"
    ~default:Log.Wfeedback


(* ----- Log with positions ------------------------------------------------- *)

type 'a pretty_printer =
  ?emitwith:(Log.event -> unit) -> ?once:bool ->
  ?pos:Position.t -> ?current:bool -> ?source:Fc_Filepath.position ->
  ?stacktrace:bool ->  ?append:(Format.formatter -> unit) -> ?echo:bool ->
  ('a,Format.formatter,unit) format -> 'a

type ('a,'b) pretty_aborter =
  ?pos:Position.t -> ?current:bool -> ?source:Fc_Filepath.position ->
  ?stacktrace:bool -> ?append:(Format.formatter -> unit) -> ?echo:bool ->
  ('a,Format.formatter,unit,'b) format4 -> 'a

let append_callstack ?(stacktrace=false) ?append ~callstack fmt =
  let pretty_hash fmt cs =
    if is_debug_key_enabled dkey_callstack_hash then
      Format.fprintf fmt "<%a> " Callstack.pretty_hash cs
  in
  Option.iter (fun append -> append fmt) append;
  if stacktrace && is_debug_key_enabled dkey_callstacks then
    match callstack with
    | None -> ()
    | Some cs ->
      (* note: the "\n" before the pretty print of the stack is required by:
         FRAMAC_LIB/analysis-scripts/make_wrapper.py *)
      Format.fprintf fmt "@\nstack: @[<hv>%a%a@]"
        pretty_hash cs
        Callstack.pretty cs

let lift_aborter (aborter : ('a,'b) Log.pretty_aborter)
  : ('a,'b) pretty_aborter =
  fun ?pos ?current ?source ?stacktrace ?append ->
  (* Extract source location *)
  match pos with
  | Some pos ->
    let callstack = Position.callstack pos in
    let source = Option.value ~default:(Position.pos pos) source
    (* Append callstack if requested *)
    and append = append_callstack ?stacktrace ?append ~callstack in
    aborter ?current:None ~source ~append
  | None ->
    let callstack = Callstack.get_current () in
    let append = append_callstack ?stacktrace ?append ~callstack in
    aborter ?current ?source ~append


let lift_printer (printer : 'a Log.pretty_printer) : 'a pretty_printer =
  fun ?emitwith ?once -> lift_aborter (printer ?emitwith ?once)

let result ?level ?dkey =
  lift_printer (result ?level ?dkey)

let feedback ?ontty ?level ?dkey  =
  lift_printer (feedback ?ontty ?level ?dkey )

let debug ?level ?dkey =
  lift_printer (debug ?level ?dkey)

let warning ?wkey : 'a pretty_printer =
  lift_printer (warning ?wkey)

let alarm ?emitwith =
  warning ~wkey:wkey_alarm ?emitwith

let error ?emitwith =
  lift_printer error ?emitwith

let abort ?pos =
  lift_aborter abort ?pos

let failure ?emitwith =
  lift_printer failure ?emitwith

let fatal ?pos =
  lift_aborter fatal ?pos
