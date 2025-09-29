(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

val current_kf_inout: unit -> Inout_type.t option

module Make (Abstract: Engine_sig.S) :
  Engine_sig.Transfer_stmt with type state = Abstract.Dom.t
                            and type value = Abstract.Val.t
                            and type loc = Abstract.Loc.location
