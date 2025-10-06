(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** Deprecated module, use {!Hashtbl} instead. *)

module type S = Hashtbl.S
[@@deprecated "Use Hashtbl.S instead."]

module Make(H: Hashtbl.HashedType) : Hashtbl.S with type key = H.t
  [@@deprecated "Use Hashtbl.Make instead."]
  [@@migrate { repl = Hashtbl.Make } ]

val hash : 'a -> int
[@@deprecated "Use Hashtbl.hash instead."]
[@@migrate { repl = Hashtbl.hash } ]

val hash_param : int -> int -> 'a -> int
[@@deprecated "Use Hashtbl.hash_param instead."]
[@@migrate { repl = Hashtbl.hash_param } ]
