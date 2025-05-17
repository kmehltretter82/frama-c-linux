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

(** This modules adapt the interface of {!Log.Messages} to be usable with
    {!Analysis_location.t}.

    [stacktrace] optional parameters controls wheter the call stack must
    be printed at the end of the message and always default to false. *)

type 'a pretty_printer =
  ?emitwith:(Log.event -> unit) -> ?once:bool ->
  aloc:Analysis_location.t -> ?stacktrace:bool ->
  ?echo:bool ->
  ('a,Format.formatter,unit) format -> 'a

type ('a,'b) pretty_aborter =
  aloc:Analysis_location.t -> ?stacktrace:bool ->
  ?echo:bool ->
  ('a,Format.formatter,unit,'b) format4 -> 'a

(** see {!Log.Messages} for documentation **)

(** Results of analysis. *)
val result : ?level:int -> ?dkey:Self.category -> 'a pretty_printer

(** Progress and feedback. *)
val feedback : ?ontty:Log.ontty -> ?level:int -> ?dkey:Self.category -> 'a pretty_printer

(** Debugging information. *)
val debug : ?level:int -> ?dkey:Self.category -> 'a pretty_printer

(** Warnings. *)
val warning : ?wkey:Self.warn_category -> 'a pretty_printer

(** Alarm emitted by the analysis. *)
val alarm : 'a pretty_printer

(** User error. *)
val error : 'a pretty_printer

(** User error stopping the plugin. *)
val abort : ('a,'b) pretty_aborter

(** Internal error of the plug-in. *)
val failure : 'a pretty_printer

(** Internal error stopping the plug-in. *)
val fatal   : ('a,'b) pretty_aborter
