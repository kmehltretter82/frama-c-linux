(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

type thread_id = int

module Make (Engine : Engine_sig.S_with_results) :
  Engine_sig.Interferences with
  type state = Engine.Dom.t
