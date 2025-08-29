(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open ProofEngine

class printer : Wtext.text ->
  object
    method on_click : (position -> unit) -> unit
    method on_backtrack : (node -> unit) -> unit
    method pp_main : Format.formatter -> tree -> unit
    method pp_node : Format.formatter -> node -> unit

    method pending : node -> unit
    method status : tree -> unit
    method tree : tree -> unit
  end
