(**************************************************************************)
(*                                                                        *)
(*  This file is part of Aorai plug-in of Frama-C.                        *)
(*                                                                        *)
(*  Copyright (C) 2007-2024                                               *)
(*    CEA (Commissariat à l'énergie atomique et aux énergies              *)
(*         alternatives)                                                  *)
(*    INRIA (Institut National de Recherche en Informatique et en         *)
(*           Automatique)                                                 *)
(*    INSA  (Institut National des Sciences Appliquees)                   *)
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

(** utilities for parsing automaton's formulas *)

(** aborts the execution using current lexbuf position as source. *)
val abort_current:
  Lexing.lexbuf -> ('a, Format.formatter, unit, 'b) format4 -> 'a

(** aborts in case the current character
    is not the beginning of a valid token. *)
val unknown_token: Lexing.lexbuf -> 'a

(** initiate a new line in the lexbuf *)
val newline: Lexing.lexbuf -> unit

(** aborts in case of an unterminated comment *)
val unterminated_comment: Lexing.lexbuf -> 'a
