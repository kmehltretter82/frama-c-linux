(*****************************************************************************)
(*                                                                           *)
(*  This file was originally part of Objective Caml                          *)
(*                                                                           *)
(*            Xavier Leroy, projet Cristal, INRIA Rocquencourt               *)
(*                                                                           *)
(*  Copyright (C) 1996 INRIA                                                 *)
(*    INRIA (Institut National de Recherche en Informatique et en            *)
(*           Automatique)                                                    *)
(*                                                                           *)
(*  All rights reserved.                                                     *)
(*                                                                           *)
(*  This file is distributed under the terms of the GNU Library General      *)
(*  Public License version 2, with the special exception on linking          *)
(*  described below. See the GNU Library General Public License version      *)
(*  2 for more details (enclosed in the file licenses/LGPLv2).               *)
(*                                                                           *)
(*  As a special exception to the GNU Library General Public License,        *)
(*  you may link, statically or dynamically, a "work that uses the Library"  *)
(*  with a publicly distributed version of the Library to                    *)
(*  produce an executable file containing portions of the Library, and       *)
(*  distribute that executable file under terms of your choice, without      *)
(*  any of the additional requirements listed in clause 6 of the GNU         *)
(*  Library General Public License.                                          *)
(*  By "a publicly distributed version of the Library",                      *)
(*  we mean either the unmodified Library as                                 *)
(*  distributed by INRIA, or a modified version of the Library that is       *)
(*  distributed under the conditions defined in clause 2 of the GNU          *)
(*  Library General Public License.  This exception does not however         *)
(*  invalidate any other reasons why the executable file might be            *)
(*  covered by the GNU Library General Public License.                       *)
(*                                                                           *)
(*  File modified by CEA (Commissariat à l'énergie atomique et aux           *)
(*                        énergies alternatives).                            *)
(*                                                                           *)
(*****************************************************************************)

module type S_Basic_Compare =
  sig
    type elt
    type t
    val empty: t
    val is_empty: t -> bool
    val mem: elt -> t -> bool
    val add: elt -> t -> t
    val singleton: elt -> t
    val remove: elt -> t -> t
    val union: t -> t -> t
    val inter: t -> t -> t
    val diff: t -> t -> t
    val compare: t -> t -> int
    val equal: t -> t -> bool
    val subset: t -> t -> bool
    val iter: (elt -> unit) -> t -> unit
    val fold: (elt -> 'a -> 'a) -> t -> 'a -> 'a
    val for_all: (elt -> bool) -> t -> bool
    val exists: (elt -> bool) -> t -> bool
    val filter: (elt -> bool) -> t -> t
    val partition: (elt -> bool) -> t -> t * t
    val cardinal: t -> int
    val elements: t -> elt list
    val choose: t -> elt
    val find: elt -> t -> elt
    val of_list: elt list -> t
  end

module type S =
  sig
    include Set.S
    val nearest_elt_le: elt -> t -> elt
    val nearest_elt_ge: elt -> t -> elt
  end

module Make(Ord: Set.OrderedType) =
  struct
    include Set.Make(Ord)

    let nearest_elt_le x =
      find_last (fun y -> y <= x)

    let nearest_elt_ge x =
      find_first (fun y -> y >= x)
  end

(*
Local Variables:
compile-command: "make -C ../../.."
End:
*)
