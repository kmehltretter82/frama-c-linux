(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2025                                               *)
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

include Datatype.S_with_collections

val main : t
val is_main : t -> bool

val id : t -> int
val label : t -> string
val find : int -> t option

(** [spawn al name kfl args] registers the creation of a thread encountered
    in Eva analysis, and either add this spawn to an existing thread analysis
    or create a new thread analysis.
    @param al the stmt and callstack of the thread creation
    @param name an optional name often defined by the memory location where the
         thread identifier will be stored
    @param kfl the list of possibly used entry points for the new thread
    @param args the list of arguments used for the thread invocation *)
val spawn :
  Analysis_location.local ->
  Concurency.Name.t option ->
  Cil_types.kernel_function list ->
  Cvalue.V.t list ->
  t list

(** [is_interrupt_handler kf] returns [true] if [kf] has been registered as an
    interrupt handler. *)
val is_interrupt_handler : Cil_types.kernel_function -> bool

(** [interrupt_handler kf] returns the thread representing the interrupt
    handler [kf]. *)
val interrupt_handler : Cil_types.kernel_function -> t

(** [interrupt_handlers ()] returns the threads representing the registered
    interrupt handlers. *)
val interrupt_handlers : unit -> t list

(* Internal state of the current analysis *)

(** Register a set of functions serving as interrupt handlers. *)
val register_interrupt_handlers : Kernel_function.Set.t -> unit

val reset_state : unit -> unit
val current : unit -> t
val set_current : t -> unit

val entry_point : t -> Kernel_function.t
