(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

include UnionFind.STORE

(** Global unique identifier *)
val id : 'a rref -> int

(** Unordered union *)
val bag: 'a list -> 'a list -> 'a list

(** Sorted, unique *)
val list : 'a rref list -> 'a rref list

(**/**)
val forge : int -> 'a rref
