(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

val current_kf_inout: unit -> Inout_type.t option

module Make (Engine: Engine_sig.S) :
  Engine_sig.Transfer_stmt with type state = Engine.Dom.t
