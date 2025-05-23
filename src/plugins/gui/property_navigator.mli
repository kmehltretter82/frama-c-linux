(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** Extension of the GUI in order to navigate in ACSL properties. *)

module Rte: sig
  type status_accessor =
    string
    * (Cil_types.kernel_function -> bool -> unit)
    * (Cil_types.kernel_function -> bool)
  val register_get_all_status : (unit -> status_accessor list) -> unit
end
