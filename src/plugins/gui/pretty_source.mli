(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** Utilities to pretty print source with located elements in a Gtk
    TextBuffer. *)

open Cil_types

type localizable = Printer_tag.localizable

module Locs: sig
  type state

  (** To call when the source buffer is about to be discarded *)
  val create: unit -> state
  val clear: state -> unit
end

(* Folds or unfolds the preconditions at callsite [stmt]. *)
val fold_preconds_at_callsite: stmt -> unit

(* Are the preconditions unfolded at statement [stmt]?
   Used to know which folding or unfolding icon to display at [stmt]. *)
val are_preconds_unfolded: stmt -> bool

val display_source :
  global list ->
  GSourceView.source_buffer ->
  host:Gtk_helper.host ->
  highlighter:(localizable -> start:int -> stop:int -> unit) ->
  selector:(button:int -> localizable -> unit) ->
  Locs.state ->
  unit
(** The selector and the highlighter are always host#protected.
    The selector will not be called when [not !Gtk_helper.gui_unlocked].
    This clears the [Locs.state] passed as argument, then fills it. *)

val hilite : Locs.state -> unit

val stmt_start: Locs.state -> stmt -> int
(** Offset at which the current statement starts in the buffer
    corresponding to [state], _without_ ACSL assertions/contracts, etc. *)

val locate_localizable : Locs.state -> localizable -> (int*int) option
(** @return Some (start,stop) in offset from start of buffer if the
    given localizable has been displayed according to [Locs.locs]. *)

val kf_of_localizable : localizable -> kernel_function option
val ki_of_localizable : localizable -> kinstr
val varinfo_of_localizable : localizable -> varinfo option

val localizable_from_locs :
  Locs.state -> file:Filepath.t -> line:int -> localizable list
(** Returns the lists of localizable in [file] at [line]
    visible in the current [Locs.state].
    This function is inefficient as it iterates on all the current
    [Locs.state]. *)
