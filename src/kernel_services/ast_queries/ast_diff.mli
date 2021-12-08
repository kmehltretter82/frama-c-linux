(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2021                                               *)
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

(** Compute diff information from an existing project.

    @since Frama-C+dev
*)

open Cil_types

(** the original project from which a diff is computed. *)
module Orig_project: State_builder.Option_ref with type data = Project.t

(** possible correspondances between new items and original ones. *)
type 'a correspondance =
  [ `Same of 'a (** symbol with identical definition has been found. *)
  | `Not_present (** no correspondance *)
  ]

(** specific correspondance for kernel functions *)
type kf_correspondance =
  [ kernel_function correspondance
  | `Same_spec of kernel_function (** body has changed, but spec is identical *)
  ]

(** varinfos correspondances *)
module Varinfo:
  State_builder.Hashtbl
  with type key = varinfo and type data = varinfo correspondance

module Compinfo:
  State_builder.Hashtbl
  with type key = compinfo and type data = compinfo correspondance

module Enuminfo:
  State_builder.Hashtbl
  with type key = enuminfo and type data = enuminfo correspondance

module Enumitem:
  State_builder.Hashtbl
  with type key = enumitem and type data = enumitem correspondance

module Typeinfo:
  State_builder.Hashtbl
  with type key = typeinfo and type data = typeinfo correspondance

module Stmt:
  State_builder.Hashtbl
  with type key = stmt and type data = stmt correspondance

module Logic_info:
  State_builder.Hashtbl
  with type key = logic_info and type data = logic_info correspondance

module Logic_type_info:
  State_builder.Hashtbl
  with type key = logic_type_info and type data = logic_type_info correspondance

module Fieldinfo:
  State_builder.Hashtbl
  with type key = fieldinfo and type data = fieldinfo correspondance

module Model_info:
  State_builder.Hashtbl
  with type key = model_info and type data = model_info correspondance

module Logic_var:
  State_builder.Hashtbl
  with type key = logic_var and type data = logic_var correspondance

module Kernel_function:
  State_builder.Hashtbl
  with type key = kernel_function and type data = kf_correspondance

module Fundec:
  State_builder.Hashtbl
  with type key = fundec and type data = fundec correspondance
