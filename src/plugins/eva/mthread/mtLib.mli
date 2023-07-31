(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2025                                               *)
(*    CEA (Commissariat à l'énergie atomique et aux énergies              *)
(*         alternatives)                                                  *)
(*                                                                        *)
(*  All rights reserved.                                                  *)
(*  Contact CEA LIST for licensing.                                       *)
(*                                                                        *)
(**************************************************************************)

(** {1 Auxiliary definitions and functions for pretty-printing } *)

(** Partially applied format-like function missing a "%a" argument *)
type poly_format_quote_a =
  { pf: 'a. (Format.formatter -> 'a -> unit) -> 'a -> unit }

(** Partially applied Log.pretty_printer value, missing its entire formatter
    (and the arguments) *)
type poly_pretty_printer =
  { ppp: 'a. ('a, Format.formatter, unit) format -> 'a }



(** Compare the tags of two OCaml values (or their values if they are
    integers). Can be used to implement the generic cases of compare functions
    on inductive types. Not for the casual user. *)
val compare_tag: 'a -> 'a -> int


val comp: ('a -> 'b -> int) -> 'a -> 'b -> ('c -> 'd -> int) -> 'c -> 'd -> int



(** Memory used by mthread so far *)
val mem: unit -> int



(** Conversion from something into something else. Returns a formatter that
    prints the error in case of failure *)
type 'a conversion_with_warning = [
  | `Success of 'a
  | `WithWarning of (Format.formatter -> unit) * 'a
]

type 'a conversion = [
  | 'a conversion_with_warning
  | `Failure of (Format.formatter -> unit)
]

exception FailMsg of (Format.formatter -> unit)

val conv_map: ('a -> 'b) -> 'a conversion -> 'b conversion

val escape_non_utf8: string -> string


(** Clear the results of the value analysis *)
val clear_value_results: unit -> unit


(** Location of the header file "mthread.h" *)
val mthread_h: unit -> Filepath.Normalized.t
