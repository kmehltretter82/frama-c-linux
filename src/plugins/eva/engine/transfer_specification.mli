(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

module Make
    (Engine: Engine_sig.S)
    (_ : Engine_sig.Transfer_logic with type state = Engine.Dom.t)
  : Engine_sig.Transfer_specification with type state = Engine.Dom.t
                                       and type value = Engine.Val.t
                                       and type location = Engine.Loc.location
