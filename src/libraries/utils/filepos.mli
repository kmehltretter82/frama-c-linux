(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** This module handle positions in a source file. [Filepos.t] is a Frama-C
    datatype, and comes with usual [compare], [equal], [hash] and [pretty]
    functions.
    @before 33.0-Arsenic This module was split between {!Filepath} and
    {!Cil_datatype.Position}.
*)

[@@@alert "-deprecated"]

(** Describes a position in a source file. *)
type t = Filepath.position = {
  pos_path : Filepath.t;
  pos_lnum : int;
  pos_bol : int;
  pos_cnum : int;
} [@@deriving show]

[@@@alert "+deprecated"]

include Datatype.S_with_collections with type t := t

(** Empty position, used as 'dummy' for [Cil_datatype.Position]. *)
val unknown : t

(** Return true if the given position is the empty position. *)
val is_unknown : t -> bool

val of_lexing_pos : Lexing.position -> t

val to_lexing_pos : t -> Lexing.position

(** Pretty-prints a position, in the format file:line. *)
val pretty : Format.formatter -> t -> unit

(** Debug printer, same than {!Filepos.pp}. *)
val pretty_debug : Format.formatter -> t -> unit

val pp_with_col : Format.formatter -> t -> unit
