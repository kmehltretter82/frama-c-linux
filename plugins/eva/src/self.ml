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

(* The help message of -eva-msg-key lists message categories by group. When
   adding a new group, also update function [print_message_categories] below. *)
type group = Concurrency | Domain

(* Each category can be a message category (optionally in a group) or a
   debug category. *)
type kind = Message of group option | Debug

(* Kind of each registered message or debug category. *)
let key_kind_tbl : (category, kind) Hashtbl.t = Hashtbl.create 11

type debug_category = category

let register_debug_category ~help name =
  assert (not (Stdlib.String.starts_with ~prefix:"debug" name));
  let name = "debug:" ^ name in
  let category = register_category ~help ~default:false name in
  Hashtbl.replace key_kind_tbl category Debug;
  category

type message_category = category

(* Makes the help message mandatory and adds an optional verbosity level
   and an optional group. *)
let register_message_category ?group ?level ~help name =
  assert (not (Stdlib.String.starts_with ~prefix:"debug" name));
  let default = Option.fold ~none:false ~some:((>=) default_verbosity) level in
  let category = register_category ~help ~default name in
  Option.iter (Hashtbl.replace dkey_verbosity category) level;
  Hashtbl.replace key_kind_tbl category (Message group);
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

let is_message_category_enabled = is_debug_key_enabled
let is_debug_category_enabled = is_debug_key_enabled

(* ----- Help message about categories -------------------------------------- *)

let pp_header fmt header = Format.fprintf fmt "@,@{<bold># %s:@}@," header
let pp_paragraph fmt = Format.fprintf fmt "@[<hov>%a@]@," Format.pp_print_text
let pp_list ?sep = List.pretty_text ?sep ?last:sep

let print_message_categories fmt =
  let get_info (key, kind) = dkey_name key, kind, get_category_help key in
  let list = sorted_list dkey_name key_kind_tbl |> List.map get_info in
  let name_length (name, _, _) = Stdlib.String.length name in
  let max_length = List.fold_left (fun acc x -> max acc (name_length x)) 0 in
  let pp_kind (kind, header) =
    let list = List.filter (fun (_, k, _) -> k = kind) list in
    let max = max_length list in
    let print_category fmt (name, _group, help) =
      Format.fprintf fmt "  %-*s : %a"
        max name pp_paragraph help;
    in
    Format.fprintf fmt "%a%a"
      pp_header header (pp_list ~sep:"" print_category) list;
  in
  List.iter pp_kind
    [ Message None, "Standard Eva message categories";
      Message (Some Concurrency),
      "Message categories about concurrency (with option -mthread)";
      Message (Some Domain),
      "Message categories for printing domain states on user directives";
      Debug, "Message categories for debug purposes" ]

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

let print_categories_and_exit () =
  let header fmt = Format.fprintf fmt "List of message categories." in
  printf ~header "@[<v>%t%t@]"
    print_message_categories print_categories_by_verbosity;
  raise Cmdline.Exit

(* Hook to register categories set by the user. *)
let () =
  Message_category.add_set_hook
    (fun _ s -> if s = "help" then print_categories_and_exit ())

(* ----- Log with positions ------------------------------------------------- *)

let key_callstacks =
  register_message_category "callstacks" ~level:9
    ~help:"print the current callstack alongside some messages"

let key_callstack_hash =
  register_message_category "callstack-hash" ~level:9
    ~help:"additionally print the current callstack hash in some messages"

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
    if is_message_category_enabled key_callstack_hash then
      Format.fprintf fmt "<%a> " Callstack.pretty_hash cs
  in
  Option.iter (fun append -> append fmt) append;
  if stacktrace && is_message_category_enabled key_callstacks then
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

let result ?level ?mkey =
  lift_printer (result ?level ?dkey:mkey)

let feedback ?ontty ?level ?mkey  =
  lift_printer (feedback ?ontty ?level ?dkey:mkey)

let printf ?level ?mkey = printf ?level ?dkey:mkey

let debug ?level ?dkey =
  lift_printer (debug ?level ?dkey)

let warning ?wkey : 'a pretty_printer =
  lift_printer (warning ?wkey)

let error ?emitwith =
  lift_printer error ?emitwith

let abort ?pos =
  lift_aborter abort ?pos

let failure ?emitwith =
  lift_printer failure ?emitwith

let fatal ?pos =
  lift_aborter fatal ?pos
