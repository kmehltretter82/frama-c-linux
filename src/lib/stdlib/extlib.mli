(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** Useful operations.
    This module does not depend of any of frama-c module. *)

val adapt_filename: string -> string
(** Ensure that the given filename has the extension "cmo" in bytecode
    and "cmxs" in native *)

val max_cpt: int -> int -> int
(** [max_cpt t1 t2] returns the maximum of [t1] and [t2] wrt the total ordering
    induced by tags creation. This ordering is defined as follows:
    forall tags t1 t2, t1 <= t2 iff t1 is before t2 in the finite sequence
    [0; 1; ..; max_int; min_int; min_int-1; -1] *)

val number_to_color: int -> int

(* ************************************************************************* *)
(** {2 Function builders} *)
(* ************************************************************************* *)

exception Unregistered_function of string
(** Never catch it yourself: let the kernel do the job.
    @since Oxygen-20120901 *)

val mk_labeled_fun: string -> 'a
(** To be used to initialized a reference over a labeled function.
    @since Oxygen-20120901
    @raise Unregistered_function when not properly initialized *)

val mk_fun: string -> ('a -> 'b) ref
(** Build a reference to an uninitialized function
    @raise Unregistered_function when not properly initialized *)

(* ************************************************************************* *)
(** {2 Tuples} *)
(* ************************************************************************* *)

val nest: 'b -> 'a * 'c -> ('a * 'b) * 'c
(** Nest the first argument with the first element of the pair given as second
    argument. *)

val flatten: ('a * 'b) * 'c -> 'a * 'b * 'c
(** Flatten the pairs into a triplet. *)

(* ************************************************************************* *)
(** {2 Strings} *)
(* ************************************************************************* *)

val make_unique_name:
  (string -> bool) -> ?sep:string -> ?start:int -> string -> int*string
(** [make_unique_name mem s] returns [(0, s)] when [(mem s)=false]
    otherwise returns [(n,new_string)] such that [new_string] is
    derived from [(s,sep,start)] and [(mem new_string)=false] and [n<>0]
    @since Oxygen-20120901 *)

(** [format_string_of_stag stag] returns the string corresponding to [stag],
    or raises an exception if the tag extension is unsupported.

    @since 22.0-Titanium
*)
val format_string_of_stag: Format.stag -> string

(* ************************************************************************* *)
(** {2 Performance} *)
(* ************************************************************************* *)

external address_of_value: 'a -> int = "address_of_value" [@@noalloc]

(* ************************************************************************* *)
(** {2 System commands} *)
(* ************************************************************************* *)

val safe_at_exit : (unit -> unit) -> unit
(** Register function to call with [Stdlib.at_exit], but only
    for non-child process (fork). The order of execution is preserved
    {i wrt} ordinary calls to [Stdlib.at_exit]. *)

(* ************************************************************************* *)
(** {2 Comparison functions} *)
(* ************************************************************************* *)

(** Use this function instead of [Stdlib.compare], as this makes
    it easier to find incorrect uses of the latter *)
external compare_basic: 'a -> 'a -> int = "%compare"
