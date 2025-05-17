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

type 'a pretty_printer =
  ?emitwith:(Log.event -> unit) -> ?once:bool ->
  aloc:Analysis_location.t -> ?stacktrace:bool ->
  ?echo:bool ->
  ('a,Format.formatter,unit) format -> 'a

type ('a,'b) pretty_aborter =
  aloc:Analysis_location.t -> ?stacktrace:bool ->
  ?echo:bool ->
  ('a,Format.formatter,unit,'b) format4 -> 'a

let append_callstack ~aloc ?(stacktrace=false) fmt =
  if stacktrace && Parameters.PrintCallstacks.get () then
    match Analysis_location.callstack aloc with
    | None -> ()
    | Some cs -> Format.fprintf fmt "@ stack: %a" Callstack.pretty cs

let lift_aborter (aborter : ('a,'b) Log.pretty_aborter)
  : ('a,'b) pretty_aborter =
  fun ~aloc ?stacktrace ->
  (* Extract source location from analysis location *)
  let source = Analysis_location.pos aloc
  (* Append callstack if requested *)
  and append = append_callstack ~aloc ?stacktrace in
  aborter ?current:None ~source ~append

let lift_printer (printer : 'a Log.pretty_printer) : 'a pretty_printer =
  fun ?emitwith ?once -> lift_aborter (printer ?emitwith ?once)

let result ?level ?dkey =
  lift_printer (Self.result ?level ?dkey)

let feedback ?ontty ?level ?dkey  =
  lift_printer (Self.feedback ?ontty ?level ?dkey )

let debug ?level ?dkey =
  lift_printer (Self.debug ?level ?dkey)

let warning ?wkey : 'a pretty_printer =
  lift_printer (Self.warning ?wkey)

let alarm ?emitwith =
  warning ~wkey:Self.wkey_alarm ?emitwith

let error ?emitwith =
  lift_printer Self.error ?emitwith

let abort ~aloc =
  lift_aborter Self.abort ~aloc

let failure ?emitwith =
  lift_printer Self.failure ?emitwith

let fatal ~aloc =
  lift_aborter Self.fatal ~aloc
