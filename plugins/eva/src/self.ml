(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

let default_verbosity = 5
let () = Plugin.set_default_verbose_level default_verbosity
let () = Plugin.is_share_visible ()

include Plugin.Register
    (struct
      let name = "Eva"
      let shortname = "eva"
      let help =
        "automatically computes variation domains for the variables of the program"
    end)

let () =
  add_plugin_output_aliases ~visible:false ~deprecated:true [ "value" ; "val" ]

let () = Verbose.set_range ~min:0 ~max:11

(* ----- Analysis state ----------------------------------------------------- *)

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

let clear_results () =
  Project.clear ~selection:(State_selection.with_dependencies state) ();
  (* Explicit clear to apply hooks on changes. *)
  ComputationState.clear ()


(* ----- Verbosity configuration -------------------------------------------- *)

(* Returns a function that re-applies all strings manually set by the user to
   parameter M. This is used to reset categories set by parameters -eva-msg-key
   and -eva-warn-key. *)
let reset_string_parameter (module M: Parameter_sig.String) =
  (* Reference to the list of strings provided by the user for parameter M.
     In Log, enabled categories are not projectified nor saved on disk, so we
     simply use a reference. *)
  let string_list = ref [] in
  (* Reference used to prevent reentry by the hook below. *)
  let active = ref true in
  (* Register all strings set by the user in [string_list] reference. *)
  let hook _ s = if !active then string_list := s :: !string_list in
  M.add_set_hook hook;
  fun () ->
    (* Avoid setting the parameter if it was not set by the user. *)
    if !string_list <> [] then begin
      active := false;
      (* Re-apply all strings in the order they were set by the user.
         Start by setting "" to ensure next strings are really applied. *)
      List.iter M.unsafe_set ("" :: List.rev !string_list);
      active := true
    end

(* Returns a function that re-applies all message and warning categories
   previously set by the user via -eva-msg-key or -eva-warn-key. *)
let reset_user_categories =
  let reset_messages = reset_string_parameter (module Message_category) in
  let reset_warnings = reset_string_parameter (module Warn_category) in
  fun () -> reset_messages (); reset_warnings ()


(* Eva message category can be bound to a verbosity level, at which it is
   automatically enabled. This table binds each category to its level. *)
let dkey_verbosity : (category, int) Hashtbl.t = Hashtbl.create 11

(* Some Eva warning categories are feedback by default, and are bound to a
   verbosity level, as for message categories. This table binds such categories
   to their level. *)
let wkey_verbosity : (warn_category, int) Hashtbl.t = Hashtbl.create 11

let sorted_list name tbl =
  let cmp (key1, _) (key2, _) = Stdlib.String.compare (name key1) (name key2) in
  Hashtbl.to_seq tbl |> List.of_seq |> List.fast_sort cmp

(* Enable/disable message and warning categories according to -eva-verbose.
   Sort keys by name so that "tag" is processed before "tag:subtag" and thus
   does not supersede the configuration of "tag:subtag". *)
let configure_verbosity () =
  let level = Verbose.get () in
  let change_message (key, i) =
    (if i <= level then add_debug_keys else del_debug_keys) key
  in
  List.iter change_message (sorted_list dkey_name dkey_verbosity);
  let change_warning (warn_category, i) =
    set_warn_status warn_category (if i <= level then Wfeedback else Winactive)
  in
  List.iter change_warning (sorted_list wkey_name wkey_verbosity);
  (* Reset all message and warning categories previously set by the user,
     which may have been erased by operations above.  *)
  reset_user_categories ()

(* ----- Keys registration -------------------------------------------------- *)

(* The help message of -eva-msg-key lists message categories by group. *)
type group = Concurrency | Domain | Debug

(* Eva message category can be bound to a group. *)
let dkey_group : (category, group) Hashtbl.t = Hashtbl.create 11

(* Makes the help message mandatory and adds an optional verbosity level
   and an optional group. *)
let register_category ?group ?level ~help name =
  let default = Option.fold ~none:false ~some:((>=) default_verbosity) level in
  let category = register_category ~help ~default name in
  Option.iter (Hashtbl.replace dkey_verbosity category) level;
  Option.iter (Hashtbl.replace dkey_group category) group;
  category

(* Default status of warning categories: feedback is associated to a verbosity
   level. *)
type warn_default = Inactive | Feedback of int | Error

(* Makes the help message of various categories mandatory, and adds a verbosity
   level to the Feedback default status. *)
let register_warn_category ~help ?default name =
  let default, level =
    match default with
    | None -> None, None
    | Some Inactive -> Some Log.Winactive, None
    | Some Error -> Some Log.Werror, None
    | Some (Feedback level) -> Some Log.Wfeedback, Some level
  in
  let category = register_warn_category ~help ?default name in
  Option.iter (Hashtbl.replace wkey_verbosity category) level;
  category

(* ----- Help message about categories -------------------------------------- *)

let pp_header fmt header = Format.fprintf fmt "@,@{<bold># %s:@}@," header
let pp_paragraph fmt = Format.fprintf fmt "@[<hov>%a@]@," Format.pp_print_text
let pp_list ?sep = List.pretty_text ?sep ?last:sep

let print_message_categories fmt =
  let get_group = Hashtbl.find_opt dkey_group in
  let get_info category =
    dkey_name category, get_group category, get_category_help category
  in
  let list = get_all_categories () |> List.map get_info in
  let name_length (name, _, _) = Stdlib.String.length name in
  let max_length = List.fold_left (fun acc x -> max acc (name_length x)) 0 in
  let pp_group (group_opt, header) =
    let list = List.filter (fun (_, group, _) -> group = group_opt) list in
    let max = max_length list in
    let print_category fmt (name, _group, help) =
      Format.fprintf fmt "  %-*s : %a"
        max name pp_paragraph help;
    in
    Format.fprintf fmt "%a%a"
      pp_header header (pp_list ~sep:"" print_category) list;
  in
  List.iter pp_group
    [ None, "Standard Eva message categories";
      Some Concurrency,
      "Message categories about concurrency (with option -mthread)";
      Some Domain,
      "Message categories for printing domain states on user directives";
      Some Debug, "Message categories for debug purposes" ]

let print_verbose_help fmt =
  Format.fprintf fmt "  %a  %a"
    pp_paragraph
    "Message categories are automatically enabled or disabled according to \
     the verbosity level. Default verbosity is 5 and can be changed with \
     -eva-verbose from 0 (no message is printed) to 11 (most categories are \
     enabled). Option -eva-msg-key can also be used to enable or disable \
     specific message categories."
    pp_paragraph
    "The verbosity level also enables some warning categories as feedback \
     messages by default. Warning categories are controlled by option \
     -eva-warn-key."

let print_categories_by_verbosity fmt =
  let category_list = sorted_list dkey_name dkey_verbosity in
  let warning_list = sorted_list wkey_name wkey_verbosity in
  let pp_level level list pp_category =
    let keep (c, i) = if level = i then Some c else None in
    let list = List.filter_map keep list in
    if not (List.is_empty list) then
      Format.fprintf fmt "   %2i: @[<hov>%a@]@,"
        level (pp_list ~sep:"@ " pp_category) list
  in
  pp_header fmt "Message categories by verbosity";
  print_verbose_help fmt;
  Format.fprintf fmt
    "@,  Message categories enabled by verbosity level:@,";
  for i = 1 to 11 do pp_level i category_list pp_category done;
  Format.fprintf fmt
    "@,  Warning categories enabled as feedback message by verbosity level:@,";
  for i = 1 to 11 do pp_level i warning_list pp_warn_category done

let print_help_message () =
  let header fmt = Format.fprintf fmt "List of message categories." in
  printf ~header "@[<v>%t%t@]"
    print_message_categories print_categories_by_verbosity;
  raise Cmdline.Exit

(* Hook to register categories set by the user. *)
let () =
  Message_category.add_set_hook
    (fun _ s -> if s = "help" then print_help_message ())


(* ----- Message categories ------------------------------------------------- *)

(* Each message category is automatically enabled at a given level of verbosity:
   0: No messages.
   1: Minimal general info (starting analysis, etc) and summary.
   2: Directives given by user: Frama_C_show_each, split, etc.
   3-4: Important information about the analysis: partitioning, imprecisions…
   5: Initial and final states.
   6-8: Advanced information about automatic behaviors.
   9: Additional information such as callstacks in messages.
   10: Progress of the analysis (equivalent to -eva-show-progress).
   11: All messages (except debug messages).
*)

let dkey_show =
  register_category "show" ~level:2
    ~help:"show values/states inferred by the analysis on directives \
           such as Frama_C_show_each and Frama_C_dump_each"

let dkey_initial_state =
  register_category "initial-state" ~level:5
    ~help:"at the start of the analysis, \
           print the initial value of global variables"

let dkey_final_states =
  register_category "final-states" ~level:5
    ~help:"at the end of the analysis, print final values inferred \
           at the return point of each analyzed function "

let dkey_summary =
  register_category "summary" ~level:1
    ~help:"print a summary of the analysis at the end, including coverage \
           and alarm numbers"

let dkey_pointer_comparison =
  register_category "pointer-comparison" ~level:7
    ~help:"messages about the evaluation of pointer comparisons"

let dkey_widening =
  register_category "widening" ~level:7
    ~help:"print a message at each point where the analysis applies a widening"

let dkey_partition =
  register_category "partition" ~level:4
    ~help:"messages about states partitioning"

let dkey_split_return =
  register_category "split-return" ~level:4
    ~help:"messages related to option -eva-split-return"

let dkey_precision_settings =
  register_category "precision-settings" ~level:3
    ~help:"messages about the automatic configuration of the analysis by \
           option -eva-precision"

let dkey_progress =
  register_category "progress" ~level:10
    ~help:"messages about the analysis progress in the C code"

let dkey_callstacks =
  register_category "callstacks" ~level:9
    ~help:"print the current callstack alongside some messages"

let dkey_callstack_hash =
  register_category "callstack-hash" ~level:9
    ~help:"additionally print the current callstack hash in some messages"

(* ----- Mthread message categories ----------------------------------------- *)

let dkey_thread_fixpoint =
  register_category "thread-fixpoint" ~group:Concurrency ~level:3
    ~help:"progress of the analysis fixpoint on threads"

let dkey_thread =
  register_category "thread" ~group:Concurrency ~level:4
    ~help:"show each operation on threads interpreted by the analysis"

let dkey_mutex =
  register_category "mutex" ~group:Concurrency ~level:8
    ~help:"show each operation on mutexes interpreted by the analysis"

let dkey_queue =
  register_category "message-queue" ~group:Concurrency ~level:8
    ~help:"show each operation on message queues interpreted by the analysis"

let dkey_data_races =
  register_category "data-races" ~group:Concurrency ~level:3
    ~help:"list of possible data-races detected by the analysis"

(* Created for documentation. *)
let _dkey_shared_memory =
  register_category "shared-memory" ~group:Concurrency
    ~help:"all messages about shared memory"

let dkey_shared_memory_zone =
  register_category "shared-memory:zone" ~group:Concurrency ~level:3
    ~help:"list of shared memory locations detected by the analysis"

let dkey_shared_memory_mutex =
  register_category "shared-memory:mutex" ~group:Concurrency ~level:4
    ~help:"list of mutexes protecting access to each shared memory location"

let dkey_shared_memory_mutex_details =
  register_category "shared-memory:mutex-details" ~group:Concurrency ~level:6
    ~help:"more details about mutexes protecting access to shared memory"

let dkey_shared_memory_by_iteration =
  register_category "shared-memory:iteration" ~group:Concurrency ~level:7
    ~help:"evolution of shared memory detected at each analysis iteration"

let dkey_shared_memory_values =
  register_category "shared-memory:values" ~group:Concurrency ~level:8
    ~help:"values read and written in shared memory during the analysis"

let dkey_global_accesses =
  register_category "global-accesses" ~group:Concurrency ~level:11
    ~help:"print all accesses to global variables during the analysis"

(* ----- Other message categories ------------------------------------------- *)

let dkey_cvalue_domain =
  register_category "d-cvalue" ~group:Domain ~level:0
    ~help:"print states of the cvalue domain"

let dkey_iterator =
  register_category "iterator" ~group:Debug
    ~help:"debug messages about the fixpoint engine on the control-flow graph \
           of functions"

let dkey_include_string_literal =
  register_category "include-string-literals" ~group:Debug ~level:11
    ~help:"when printing a state, \
           also include globals representing string literals"

(* ----- Warning categories ------------------------------------------------- *)

let wkey_alarm =
  register_warn_category "alarm"
    ~help:"warnings for each possible undefined behavior detected \
           by the analysis"

let wkey_volatile =
  register_warn_category "volatile"
    ~help:"a non-volatile lvalue may point to a volatile memory location"

let wkey_locals_escaping =
  register_warn_category "locals-escaping"
    ~help:"a pointer p points to an out of scope local variable \
           (any use of p also generates an alarm)"

let _wkey_garbled_mix =
  register_warn_category "garbled-mix"
    ~help:"warnings about very imprecise values inferred for pointers, \
           named garbled mix"

let wkey_garbled_mix_write =
  register_warn_category "garbled-mix:write"
    ~help:"the interpretation of an assignment creates a garbled mix"
    ~default:(Feedback 3)

let wkey_garbled_mix_assigns =
  register_warn_category "garbled-mix:assigns"
    ~help:"the interpretation of a specification creates a garbled mix"
    ~default:(Feedback 3)

let wkey_garbled_mix_summary =
  register_warn_category "garbled-mix:summary"
    ~help:"list the origins of garbled mix at the end of an analysis"
    ~default:(Feedback 3)

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
    ~help:"messages about loop unrolling"

let wkey_loop_unroll_auto =
  register_warn_category "loop-unroll:auto"
    ~help:"a loop is automatically unrolled by -eva-auto-loop-unroll"
    ~default:(Feedback 4)

let wkey_loop_unroll_partial =
  register_warn_category "loop-unroll:partial"
    ~help:"a loop has been partially but not completely unrolled"
    ~default:(Feedback 4)

let wkey_missing_loop_unroll =
  register_warn_category "loop-unroll:missing"
    ~help:"a loop has no unroll annotation"
    ~default:Inactive

let wkey_missing_loop_unroll_for =
  register_warn_category "loop-unroll:missing:for"
    ~help:"a for loop has no unroll annotation"
    ~default:Inactive

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
    ~default:(Feedback 4)

let wkey_missing_assigns =
  register_warn_category "assigns:missing"
    ~help:"assigns clauses are missing or incomplete from an ACSL \
           specification on which the analysis soundness relies"
    ~default:Error

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
    ~default:(Feedback 2)

let wkey_recursion =
  register_warn_category "recursion"
    ~help:"a recursive call is analyzed"
    ~default:(Feedback 3)

let wkey_acsl =
  register_warn_category "acsl"
    ~help:"messages about evaluation of ACSL terms and predicates"
    ~default:(Feedback 4)

let wkey_acsl_unsupported =
  register_warn_category "acsl:unsupported"
    ~help:"messages about ACSL terms not supported by Eva"
    ~default:(Feedback 4)

(* ----- Log with positions ------------------------------------------------- *)

type 'a pretty_printer =
  ?emitwith:(Log.event -> unit) -> ?once:bool ->
  ?pos:Position.t -> ?current:bool -> ?source:Fileloc.t ->
  ?stacktrace:bool ->  ?append:(Format.formatter -> unit) -> ?echo:bool ->
  ('a,Format.formatter,unit) format -> 'a

type ('a,'b) pretty_aborter =
  ?pos:Position.t -> ?current:bool -> ?source:Fileloc.t ->
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
    let source = Option.value ~default:(Position.loc pos) source
    (* Append callstack if requested *)
    and append = append_callstack ?stacktrace ?append ~callstack in
    aborter ?current:None ~source ~append
  | None ->
    let callstack = Current_callstack.get () in
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
