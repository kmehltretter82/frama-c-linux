(**************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2023                                               *)
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

val why3_version : string
val config : unit -> Why3.Whyconf.config
val configure : unit -> unit
val set_procs : int -> unit

type t = Why3.Whyconf.prover

val find_opt : string -> t option

type fallback = Exact of t | Fallback of t | NotFound
val find_fallback : string -> fallback

val ident_why3 : t -> string
val ident_wp : t -> string
val title : ?version:bool -> t -> string
val name : t -> string
val version : t -> string
val altern : t -> string
val compare : t -> t -> int

val provers : unit -> t list
val provers_set : unit -> Why3.Whyconf.Sprover.t
val is_auto : t -> bool
val is_available : t -> bool
val is_mainstream : t -> bool
val has_shortcut : t -> string -> bool

(**************************************************************************)
