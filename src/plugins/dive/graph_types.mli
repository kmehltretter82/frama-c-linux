(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C plug-in `Dive'.                      *)
(*                                                                        *)
(*  Copyright (C) 2018                                                    *)
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

type node_kind =
  | Scalar of Cil_types.varinfo * Cil_types.typ * Cil_types.offset
  | Composite of Cil_types.varinfo
  | Scattered of Cil_types.lval
  | Alarm of Cil_types.stmt * Cil_types.exp
  | File (* Dummy node, hack for Ocamlgraph Graphviz Dot module *)

type node_locality = {
  loc_file : string;
  loc_function : Cil_types.kernel_function option;
}

type node = {
  node_key : int;
  node_kind : node_kind;
  node_locality : node_locality;
  mutable node_imprecise : bool;
  mutable node_deps_computed : bool;
}

type dependency_kind = Callee | Data | Address | Control

type dependency = {
  dependency_key : int;
  dependency_kind : dependency_kind;
  mutable dependency_multiple : bool;
}
