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

(** Runtime Error Annotation Generation plugin. *)

(** Same result as having [-rte] on the command line*)
val compute : unit -> unit

(** Generates RTE for a single function. Uses the status of the various
    RTE options do decide which kinds of annotations must be generated.
*)
val annotate_kf : Cil_types.kernel_function -> unit

(** Generates all possible RTE for a given function. *)
val do_all_rte : Cil_types.kernel_function -> unit

(** Generates all possible RTE except pre-conditions for a given function. *)
val do_rte : Cil_types.kernel_function -> unit

val self: State.t

type status_accessor =
  string (* name *)
  * (Cil_types.kernel_function -> bool -> unit) (* for each kf and each kind of
                                                   annotation, set/unset the
                                                   fact that there has been
                                                   generated *)
  * (Cil_types.kernel_function -> bool) (* is this kind of annotation generated
                                           in kf? *)

val get_all_status : unit -> status_accessor list
val get_divMod_status : unit -> status_accessor
val get_initialized_status: unit -> status_accessor
val get_memAccess_status : unit -> status_accessor
val get_pointerCall_status: unit -> status_accessor
val get_signedOv_status : unit -> status_accessor
val get_signed_downCast_status : unit -> status_accessor
val get_unsignedOv_status : unit -> status_accessor
val get_unsignedDownCast_status : unit -> status_accessor
val get_pointer_downcast_status : unit -> status_accessor
val get_float_to_int_status : unit -> status_accessor
val get_finite_float_status : unit -> status_accessor
val get_pointer_value_status : unit -> status_accessor
val get_bool_value_status : unit -> status_accessor
