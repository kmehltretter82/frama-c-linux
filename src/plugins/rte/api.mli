(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** Runtime Error Annotation Generation plugin. *)

(** Same result as having [-rte] on the command line*)
val compute : unit -> unit
[@@ migrate { repl = RteGen.compute }]

(** Generates RTE for a single function. Uses the status of the various
    RTE options do decide which kinds of annotations must be generated.
*)
val annotate_kf : Cil_types.kernel_function -> unit
[@@ migrate { repl = RteGen.Visit.annotate }]

(** Generates all possible RTE for a given function. *)
val do_all_rte : Cil_types.kernel_function -> unit
[@@ deprecated "Use RteGen.Visit.annotate instead"]

(** Generates all possible RTE except pre-conditions for a given function. *)
val do_rte : Cil_types.kernel_function -> unit
[@@ deprecated "Use RteGen.Visit.annotate instead"]

val self: State.t
[@@ migrate { repl = RteGen.Generator.self }]

type status_accessor =
  string (* name *)
  * (Cil_types.kernel_function -> bool -> unit) (* for each kf and each kind of
                                                   annotation, set/unset the
                                                   fact that there has been
                                                   generated *)
  * (Cil_types.kernel_function -> bool) (* is this kind of annotation generated
                                           in kf? *)

val get_all_status : unit -> status_accessor list
[@@ migrate { repl = fun () -> RteGen.Generator.all_statuses }]
val get_divMod_status : unit -> status_accessor
[@@ migrate { repl = fun () -> RteGen.Generator.Div_mod.accessor }]
val get_initialized_status: unit -> status_accessor
[@@ migrate { repl = fun () -> RteGen.Generator.Initialized.accessor }]
val get_memAccess_status : unit -> status_accessor
[@@ migrate { repl = fun () -> RteGen.Generator.Mem_access.accessor }]
val get_pointerCall_status: unit -> status_accessor
[@@ migrate { repl = fun () -> RteGen.Generator.Pointer_call.accessor }]
val get_signedOv_status : unit -> status_accessor
[@@ migrate { repl = fun () -> RteGen.Generator.Signed_overflow.accessor }]
val get_signed_downCast_status : unit -> status_accessor
[@@ migrate { repl = fun () -> RteGen.Generator.Signed_downcast.accessor }]
val get_unsignedOv_status : unit -> status_accessor
[@@ migrate { repl = fun () -> RteGen.Generator.Unsigned_overflow.accessor }]
val get_unsignedDownCast_status : unit -> status_accessor
[@@ migrate { repl = fun () -> RteGen.Generator.Unsigned_downcast.accessor }]
val get_pointer_downcast_status : unit -> status_accessor
[@@ migrate { repl = fun () -> RteGen.Generator.Pointer_downcast.accessor }]
val get_float_to_int_status : unit -> status_accessor
[@@ migrate { repl = fun () -> RteGen.Generator.Float_to_int.accessor }]
val get_finite_float_status : unit -> status_accessor
[@@ migrate { repl = fun () -> RteGen.Generator.Finite_float.accessor }]
val get_pointer_value_status : unit -> status_accessor
[@@ migrate { repl = fun () -> RteGen.Generator.Pointer_value.accessor }]
val get_bool_value_status : unit -> status_accessor
[@@ migrate { repl = fun () -> RteGen.Generator.Bool_value.accessor }]
