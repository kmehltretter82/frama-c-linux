(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2024                                               *)
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

(** Module dedicated to asynchronous actions.
    @since 29.0-Copper
    @before 29.0-Copper these features were in a module named Db
*)

(** Registered daemon on progress. *)
type daemon

(** [on_progress ?debounced ?on_delayed trigger] registers [trigger] as new
    daemon to be executed on each {!yield}.
    @param debounced the least amount of time between two successive calls to
    the daemon, in milliseconds (default is 0ms).
    @param on_delayed callback is invoked as soon as the time since the last
    {!yield} is greater than [debounced] milliseconds (or 100ms at least).
    @param on_finished callback is invoked when the callback is unregistered.
*)
val on_progress :
  ?debounced:int -> ?on_delayed:(int -> unit) -> ?on_finished:(unit -> unit) ->
  (unit -> unit) -> daemon

(** Unregister the [daemon]. *)
val off_progress : daemon -> unit

(** [while_progress ?debounced ?on_delayed ?on_finished trigger] is similar to
    [on_progress] but the daemon is automatically unregistered
    as soon as [trigger] returns [false].
    Same optional parameters than [on_progress].
*)
val while_progress :
  ?debounced:int -> ?on_delayed:(int -> unit) -> ?on_finished:(unit -> unit) ->
  (unit -> bool) -> unit

(** [with_progress ?debounced ?on_delayed trigger job data] executes the given
    [job] on [data] while registering [trigger] as temporary (debounced) daemon.
    The daemon is finally unregistered at the end of the computation.
    Same optional parameters than [on_progress].
*)
val with_progress :
  ?debounced:int -> ?on_delayed:(int -> unit) -> ?on_finished:(unit -> unit) ->
  (unit -> unit) -> ('a -> 'b) -> 'a -> 'b

(** Trigger all daemons immediately. *)
val flush : unit -> unit

(** Trigger all registered daemons (debounced).
    This function should be called from time to time by all analysers taking
    time. In GUI or Server mode, this will make the clients responsive. *)
val yield : unit -> unit

(** Interrupt the currently running job: the next call to {!yield}
    will raise a [Cancel] exception. *)
val cancel : unit -> unit

(** Pauses the currently running process for the specified time, in milliseconds.
    Registered daemons, if any, will be regularly triggered during this waiting
    time at a reasonable period with respect to their debouncing constraints.
*)
val sleep : int -> unit

(** This exception may be raised by {!yield} to interrupt computations. *)
exception Cancel
