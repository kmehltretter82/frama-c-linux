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

type 'a domain = (module Abstract.Domain.External with type state = 'a)
type thread_id = int
type t

(** Current interferences, set by Mthread *)
val current : t ref

(** Create a new interferences abstract representation, fitted for the given
    domain*)
val initial : 'a domain -> t

type add_result =
  | Updated
  | NoChanges

(** Add the last Eva analysis results to the given interferences abstract
    representation. *)
val add_last_analysis :
  domain:'a domain ->
  get_state:(Analysis_location.local -> 'a Lattice_bounds.or_top_bottom) ->
  t -> Thread.t -> Analysis_location.local list -> Base.Hptset.t -> add_result

(** Inject current interferences to an abstract state. If activated,
    the Mthread domain helps filtering applicable interferences. This function
    is the identity if the Mthread domain can infer that no shared memory has
    been read or written during the last transfer function. *)
val inject : domain:'a domain -> 'a -> 'a

(** Are there any current interferences to inject? *)
val is_empty : unit -> bool
