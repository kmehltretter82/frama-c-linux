(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** Statuses of preconditions specialized at a given call-point. *)

open Cil_types

val setup_precondition_proxy: kernel_function -> Property.t -> unit
(** [setup_precondition_proxy kf p] creates a new property for [p]
    at each syntactic call site of [kf], representing the status
    of [p] at this particular call. [p] is considered proven if and
    only if all its instances are themselves proven. *)

val setup_all_preconditions_proxies: kernel_function -> unit
(** [setup_all_preconditions_proxies kf] is equivalent to calling
    [setup_precondition_proxy] on all the requires of [kf]. *)

val precondition_at_call:
  kernel_function -> Property.t -> stmt -> Property.t
(** [property_at_call kf p stmt] returns the property corresponding to the
    status of the precondition [p] at the call [stmt]. If [stmt]  is a call
    through a pointer, the property at this call is created automatically
    if needed. For direct calls, [setup_precondition_proxy] must have been
    called before. *)

val all_call_preconditions_at:
  warn_missing:bool -> kernel_function -> stmt -> (Property.t * Property.t) list
(** [all_call_preconditions_at create kf stmt] returns the copies of all the
    requires of [kf] for the call statement at [stmt].  The first property in
    the tuple is the require,  the second the copy at the call point.
    If [warn_missing] is true and a copy has not yet been created an error
    is raised. *)

val all_functions_with_preconditions: stmt -> Kernel_function.Hptset.t
(** Returns the set of functions that can be called at the given statement
    and for which a precondition has been specialized at this call.
    Those functions are registered when the function {!precondition_at_call}
    is called. *)

val replace_call_precondition: Property.t -> stmt -> Property.t -> unit
(** [replace_for_call pre stmt pre_at_call] states that [pre_at_call]
    is the property corresponding to the status of [pre] at call [stmt].
    The previous property, if any, is removed. Beware that this may also
    remove some already proved statuses *)

val transpose_term_at_callsite:
  formals:varinfo list -> concretes:exp list ->
  term -> term option
(** [transpose_pred_at_callsite ~formals ~concretes t] substitutes in term [t]
    formal parameters with concrete values and move [Pre] labels to [Here].
    Returns [None] if ever the address of a formal is taken.
    @since Frama-C 33.0-Arsenic
*)

val transpose_pred_at_callsite:
  formals:varinfo list -> concretes:exp list ->
  predicate -> predicate option
(** Same as to [transpose_term_at_callsite] for predicates.
    @since Frama-C 33.0-Arsenic
*)

val transpose_ipred_at_callsite:
  formals:varinfo list -> concretes:exp list ->
  identified_predicate -> identified_predicate option
(** Same as to [transpose_term_at_callsite] for identified predicates.
    @since Frama-C 33.0-Arsenic
*)
