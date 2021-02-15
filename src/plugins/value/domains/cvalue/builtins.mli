(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2020                                               *)
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

(** Value analysis builtin shipped with Frama-C, more efficient than their
    equivalent in C *)

exception Invalid_nb_of_args of int
exception Outside_builtin_possibilities

type builtin_type = unit -> Cil_types.typ * Cil_types.typ list
type cacheable = Eval.cacheable

type call_result = {
  c_values:
    (Cvalue.V_Offsetmap.t option
     * Cvalue.Model.t)
    list;
  c_clobbered: Base.SetLattice.t;
  c_cacheable: cacheable;
  c_from: (Function_Froms.froms * Locations.Zone.t) option
}

type builtin =
  Cvalue.Model.t ->
  (Cil_types.exp * Cvalue.V.t * Cvalue.V_Offsetmap.t) list ->
  call_result

(** [register_builtin name ?replace ?typ f] registers the ocaml function [f]
    as a builtin to be used instead of the C function of name [name].
    If [replace] is provided, the builtin is also used instead of the C function
    of name [replace], unless option -eva-builtin-auto is disabled.
    If [typ] is provided, consistency between the expected [typ] and the type of
    the C function is checked before using the builtin. *)
val register_builtin:
  string -> ?replace:string ->
  ?typ:builtin_type -> builtin -> unit

(** Prepares the builtins to be used for an analysis. Must be called at the
    beginning of each Eva analysis. Warns about builtins of incompatible types,
    builtins without an available specification and builtins overriding function
    definitions. *)
val prepare_builtins: unit -> unit

(** [clobbered_set_from_ret state ret] can be used for functions that return
    a pointer to where they have written some data. It returns all the bases
    of [ret] whose contents may contain local variables. *)
val clobbered_set_from_ret: Cvalue.Model.t -> Cvalue.V.t -> Base.SetLattice.t

type call = (Precise_locs.precise_location, Cvalue.V.t) Eval.call
type result = Cvalue.Model.t * Locals_scoping.clobbered_set

(** Is a given function replaced by a builtin? *)
val is_builtin_overridden: Cil_types.kernel_function -> bool

(** Returns the cvalue builtin for a function, if any. Also returns the name of
    the builtin and the specification of the function; the preconditions must be
    evaluated along with the builtin.
    [prepare_builtins] should have been called before using this function. *)
val find_builtin_override:
  Cil_types.kernel_function -> (string * builtin * Cil_types.funspec) option

(* Applies a cvalue builtin for the given call, in the given cvalue state. *)
val apply_builtin:
  builtin -> call -> Cvalue.Model.t -> result list * cacheable


(*
Local Variables:
compile-command: "make -C ../../../../.."
End:
*)
