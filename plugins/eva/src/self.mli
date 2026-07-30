(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

include Plugin.General_services

val proxy: State_builder.Proxy.t
val state: State.t

(** Return [true] iff the value analysis has been done. *)
val is_computed: unit -> bool

(** Clears the results of the Eva analysis. *)
val clear_results: unit -> unit

(** Computation state of the analysis. *)
type computation_state = NotComputed | Computing | Computed | Aborted

(** The current computation state of the analysis, updated by
    [force_compute] and states updates. *)
module ComputationState : State_builder.Ref with type data = computation_state

(** Exception used to cleanly abort the analysis (without killing Frama-C). *)
exception Abort

(** {2 Message categories.} *)

(** The help message of -eva-msg-key lists message categories by group.
    Categories without group are standard messages listed first. *)
type group = Concurrency | Domain

(** Same as Log's {!register_category}, but [help] is mandatory, and a group and
    verbosity level can be associated to the category. *)
val register_category:
  ?group:group -> ?level:int -> help:string -> string -> category

(** Is a given message category currently enabled? *)
val is_category_enabled: category -> bool

(** Use [Key.callstacks] instead. *)
val key_callstacks : category

(** {2 Debug categories.} *)

(** Category for debug messages. *)
type debug_category

(** Registers a debug category. The name is prefixed by [debug:]. *)
val register_debug_category: help:string -> string -> debug_category

(** Is a given debug category currently enabled? *)
val is_debug_category_enabled: debug_category -> bool

(** {2 Warning categories.} *)

(* Default status of warning categories: feedback is associated to a verbosity
   level. *)
type warn_default = Inactive | Feedback of int | Error

(** Same as Log's {!register_warn_category}, but [help] is mandatory and the
    [Feedback] default status is associated to a verbosity level. *)
val register_warn_category:
  help:string -> ?default:warn_default -> string -> warn_category

(** {2 Logging.} *)

(** This modules adapt the interface of {!Log.Messages} to be usable with
    {!Position.t}.

    If [position] is given, then message will be located at this position.
    Otherwise if [current] or [source] are given, then the current position
    tracked by the kernel or the given location will respectively be used.
    [stacktrace] optional parameter controls whether the call stack must
    be printed at the end of the message and always default to false.

    See {!Log.Messages} for documentation *)

type 'a pretty_printer =
  ?emitwith:(Log.event -> unit) -> ?once:bool ->
  ?pos:Position.t -> ?current:bool -> ?source:Fileloc.t ->
  ?stacktrace:bool ->  ?append:(Format.formatter -> unit) -> ?echo:bool ->
  ('a,Format.formatter,unit) format -> 'a

type ('a,'b) pretty_aborter =
  ?pos:Position.t -> ?current:bool -> ?source:Fileloc.t ->
  ?stacktrace:bool ->  ?append:(Format.formatter -> unit) -> ?echo:bool ->
  ('a,Format.formatter,unit,'b) format4 -> 'a

(** Results of analysis. *)
val result : ?level:int -> ?dkey:category -> 'a pretty_printer

(** Progress and feedback. *)
val feedback : ?ontty:Log.ontty -> ?level:int -> ?dkey:category -> 'a pretty_printer

(** Debugging information. *)
val debug : ?level:int -> ?dkey:debug_category -> 'a pretty_printer

(** Warnings. *)
val warning : ?wkey:warn_category -> 'a pretty_printer

(** User error. *)
val error : 'a pretty_printer

(** User error stopping the plugin. *)
val abort : ('a,'b) pretty_aborter

(** Internal error of the plug-in. *)
val failure : 'a pretty_printer

(** Internal error stopping the plug-in. *)
val fatal   : ('a,'b) pretty_aborter


(** Called at the beginning of the analysis to configure Eva verbosity,
    by automatically enabling/disabling message keys. *)
val configure_verbosity : unit -> unit

(** Prints help message about message categories. *)
val print_categories_and_exit : unit -> Cmdline.exit
