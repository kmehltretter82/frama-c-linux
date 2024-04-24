(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2024                                               *)
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

let expr_inputs = Inputs.expr
let stmt_inputs = Inputs.statement
let kf_inputs = Inputs.get_internal
let kf_external_inputs = Inputs.get_external

let stmt_outputs = Outputs.statement
let kf_outputs = Outputs.get_internal
let kf_external_outputs = Outputs.get_external

let get_precise_inout = Operational_inputs.get_internal_precise

let states = [ Inputs.self; Outputs.self ]
let proxy = State_builder.Proxy.(create "inout" Both states)
let self = State_builder.Proxy.get proxy
