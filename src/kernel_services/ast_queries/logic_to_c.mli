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

open Cil_types

exception No_conversion

val logic_type_to_typ : logic_type -> typ
val logic_var_to_var : logic_var -> varinfo

val loc_lval_to_lval : ?result:varinfo -> term_lval -> lval list
val loc_lhost_to_lhost : ?result:varinfo -> term_lhost -> lhost list
val loc_offset_to_offset : ?result:varinfo -> term_offset -> offset list

val loc_to_exp : ?result:varinfo -> term -> exp list
(** @return a list of C expressions.
    @raise No_conversion if the argument is not a valid set of
    expressions. *)

val loc_to_lval : ?result:varinfo -> term -> lval list
(** @return a list of C locations.
    @raise No_conversion if the argument is not a valid set of
    left values. *)

val loc_to_offset : ?result:varinfo -> term -> offset list
(** @return a list of C offset provided the term denotes locations who
    have all the same base address.
    @raise No_conversion if the given term does not match the precondition *)

val term_lval_to_lval : ?result:varinfo -> term_lval -> lval
(** @raise No_conversion if the argument is not a left value. *)

val term_to_lval : ?result:varinfo -> term -> lval
(** @raise No_conversion if the argument is not a left value. *)

val term_to_exp : ?result:varinfo -> term -> exp
(** @raise No_conversion if the argument is not a valid expression. *)

val term_offset_to_offset : ?result:varinfo -> term_offset -> offset
(** @raise No_conversion if the argument is not a valid offset. *)
