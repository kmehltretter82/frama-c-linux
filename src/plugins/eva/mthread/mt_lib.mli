(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)


(** Compare the tags of two OCaml values (or their values if they are
    integers). Can be used to implement the generic cases of compare functions
    on inductive types. Not for the casual user. *)
val compare_tag: 'a -> 'a -> int


val comp: ('a -> 'b -> int) -> 'a -> 'b -> ('c -> 'd -> int) -> 'c -> 'd -> int



(** Conversion from something into something else. Returns a formatter that
    prints the error in case of failure *)
type 'a conversion_with_warning = [
  | `Success of 'a
  | `WithWarning of (Format.formatter -> unit) * 'a
]

type 'a conversion = [
  | `Success of 'a
  | `Failure of (Format.formatter -> unit)
]

val escape_non_utf8: string -> string


(** Clear the results of the value analysis *)
val clear_value_results: unit -> unit


(** Location of the header file "mthread.h" *)
val mthread_h: unit -> Filepath.t

(** Remove specialchars forbidden in file names *)
val sanitize_filename: ?char:char -> string -> string
