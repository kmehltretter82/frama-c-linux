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

(** Utilitary functions on the {!Eva.Froms.Memory.t} type. *)

type t = Eva.Assigns.Memory.t

val top : t

val bind_var: Cil_types.varinfo -> Eva.Deps.t -> t -> t
val unbind_var: Cil_types.varinfo -> t -> t

val map : (Eva.Deps.t -> Eva.Deps.t) -> t -> t

val compose : t -> t -> t
(** Sequential composition. See {!DepsOrUnassigned.compose}. *)

val substitute : t -> Eva.Deps.t -> Eva.Deps.t
(** [substitute m d] applies [m] to [d] so that any dependency in [d] is
    expressed using the dependencies already present in [m]. For example,
    [substitute 'x From y' 'x'] returns ['y']. *)

(** {2 Dependencies for [\result]} *)

type return = Eva.Deps.t
(* Currently, this type is equal to [Eva.Deps.t]. However, some of the functions
   below are more precise, and will be more useful when 'return' is
   represented by a precise offsetmap. This would also require changing
   the type of the [deps.return] of type Eva.Froms.t. *)

(** Default value to use for storing the dependencies of [\result] *)
val default_return: return

(** Completely imprecise return *)
val top_return: return

(** Completely imprecise return of the given size *)
val top_return_size: Int_Base.t -> return

(** Add some dependencies to [\result], between bits [start] and
    [start+size-1], to the [Deps.t] value; default value for [start] is 0.
    If [m] is specified, the dependencies are added to it. Otherwise,
    {!default_return} is used. *)
val add_to_return:
  ?start:int -> size:Int_Base.t -> ?m:return -> Eva.Deps.t -> return

val collapse_return: return -> Eva.Deps.t

(** {2 Pretty-printing} *)

(** Display dependencies of a function, using the function's type to improve
    readability *)
val pretty_with_type: Cil_types.typ -> Eva.Assigns.t Pretty_utils.formatter

(** Display dependencies of a function, using the function's type to improve
    readability, separating direct and indirect dependencies *)
val pretty_with_type_indirect:
  Cil_types.typ ->
  Eva.Assigns.t Pretty_utils.formatter
