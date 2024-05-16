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

let self = Functionwise.self
let compute = Functionwise.compute
let compute_all = Functionwise.compute_all
let is_computed = Functionwise.is_computed
let get = Functionwise.get
let pretty = Functionwise.pretty

let access zone mem = Eva.Assigns.Memory.find mem zone

let display fmt = From_register.display (Some fmt)

let compute_all_calldeps = Callwise.compute_all_calldeps
module Callwise = struct
  let iter = Callwise.iter
  let find = Callwise.find
end
