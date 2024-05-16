(**************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2024                                               *)
(*    CEA (Commissariat a l'energie atomique et aux energies              *)
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

open Lang.F

(** Smart-constructors for building Qed terms from the MemAddr Why3 module
    symbols. Types indicates in the documentation are Why3 types, not OCaml
    types.

    @since 29.0-Copper
*)

val t_addr : Lang.tau
(** Pointer type : addr *)

(** {2 Basic constructors} *)

val base : term -> term
(** [base(a: addr) : int = a.base] *)

val offset : term -> term
(** [offset(a: addr) : int = a.offset] *)

val null : term
(** [null : addr = { base = 0 ; offset = 0 }] *)

val mk_addr : term -> term -> term
(** [mk_addr(base: int)(offset: int) : addr = { base ; offset }] *)

val global : term -> term
(** [global(base: int) : addr = { base ; offset = 0 }] *)

val shift : term -> term -> term
(** [shift (a: addr) (k: int) : addr = { a with offset = a.offset + k } ]*)

val addr_lt : term -> term -> pred
(** [addr_lt(a: addr) (b: addr) = a < b] *)

val addr_le : term -> term -> pred
(** [addr_le(a: addr) (b: addr) = a <= b] *)

val addr_of_int : term -> term
(** [addr_of_int(i: int) : addr]
    Abstract: Conversion from integer to address
*)

val int_of_addr : term -> term
(** [int_of_addr (a: addr) : int]
    Abstract: Conversion from address to integer
*)

val base_offset : term -> term -> term
(** [base_offset(base: int)(offset: int) : int]
    Converts a {i logic} offset (which is actually the address of a memory cell
    in a given memory model into an offset in {i bytes}.
*)

(** {2 Symbols related to the table of allocation (int -> int)} *)

val valid_rd : term -> term -> term -> pred
(** [valid_rd(m: malloc)(a: addr)(l: length)] *)

val valid_rw : term -> term -> term -> pred
(** [valid_rw(m: malloc)(a: addr)(l: length)] *)

val valid_obj : term -> term -> term -> pred
(** [valid_obj(m: malloc)(a: addr)(l: length)] *)

val invalid : term -> term -> term -> pred
(** [invalid(m: malloc)(a: addr)(l: length)]
    Invalidity means that the {i entire} range of addresses is invalid.
*)

val region : term -> term
(** [region(base: int) : int]
    The memory region a base belongs to.
*)

val linked : term -> pred
(** [linked(m: malloc)] *)

val register :
  ?base:(term list -> term) ->
  ?offset:(term list -> term) ->
  ?equal:(term -> term -> pred) ->
  ?linear:bool -> Lang.lfun -> unit
(** Register simplifiers for functions producing [addr] terms:
    - [~base es] is the simplifier for [(f es).base]
    - [~offset es] is the simplifier for [(f es).offset]
    - [~linear:true] register simplifier [f(f(p,i),k)=f(p,i+j)] on [f]
    - [~equal a b] is the [set_eq_builtin] for [f]

    The equality builtin is wrapped inside a default builtin that
    compares [f es] by computing [base] and [offset].
*)

(** {2 Memory model parameterized inclusion and separation} *)

val included :
  shift:('loc -> Ctypes.c_object -> term -> 'loc) ->
  addrof:('loc -> term) ->
  sizeof:(Ctypes.c_object -> term) ->
  'loc Sigs.rloc -> 'loc Sigs.rloc -> pred
(** [included ~shift ~addrof ~sizeof r1 r2] builds a predicate that checks
    whether [r1] is included in [r2].
    - [shift loc obj k]: [loc] shifted of [k] [obj] in the memory model,
    - [addrof loc]: [loc] translated into a [term] in the memory model,
    - [sizeof obj]: the length of [obj] in the memory model.
*)

val separated :
  shift:('loc -> Ctypes.c_object -> term -> 'loc) ->
  addrof:('loc -> term) ->
  sizeof:(Ctypes.c_object -> term) ->
  'loc Sigs.rloc -> 'loc Sigs.rloc -> pred
(** [separated ~shift ~addrof ~sizeof r1 r2] builds a predicate that checks
    whether [r1] and [r2] are separated.
    - [shift loc obj k]: [loc] shifted of [k] [obj] in the memory model,
    - [addrof loc]: [loc] translated into a [term] in the memory model,
    - [sizeof obj]: the length of [obj] in the memory model.
*)

(** {2 Qed symbols identification} *)

val is_p_valid_rd  : Lang.lfun -> bool
val is_p_valid_rw  : Lang.lfun -> bool
val is_p_valid_obj : Lang.lfun -> bool
val is_p_invalid   : Lang.lfun -> bool
val is_f_global    : Lang.lfun -> bool

(** {2 Raw Qed symbols} *)
(** Use them with care, for building terms, prefer above constructors *)

val p_separated : Lang.lfun
val p_included : Lang.lfun

(** {2 Qed simplification procedures} *)

val is_separated : term list -> Qed.Logic.maybe
(** [is_separated [ a ; la ; b ; lb ]]
    Try to solve with Qed that separated(a, la, b, lb)
*)

val is_included : term list -> Qed.Logic.maybe
(** [is_included [ a ; la ; b ; lb ]]
    Try to solve with Qed that included(a, la, b, lb)
*)
