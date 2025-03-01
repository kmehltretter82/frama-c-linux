(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2023                                               *)
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

open Cil_types

(** All functions below raise the exception Not_found when the argument cannot
    be imported. *)

val import_varinfo: varinfo -> varinfo
val import_base: Base.t -> Base.t
val import_bases: Base.Hptset.t -> Base.Hptset.t
val import_zone: Locations.Zone.t -> Locations.Zone.t
val import_deps: Deps.t -> Deps.t
val import_cvalue: Cvalue.V.t -> Cvalue.V.t
val import_offsetmap: Cvalue.V_Offsetmap.t -> Cvalue.V_Offsetmap.t

val import_expr: exp -> exp
val import_lval: lval -> lval

val import_callsite_kf: Kernel_function.t -> Kernel_function.t
val import_widening_kf: Kernel_function.t -> Kernel_function.t
val import_callsite_stmt:  Cil_datatype.Stmt.t -> Cil_datatype.Stmt.t
val import_widening_stmt:  Cil_datatype.Stmt.t -> Cil_datatype.Stmt.t
val import_inout_kf: Kernel_function.t -> Kernel_function.t

val import_inout: Inout_type.t -> Inout_type.t
