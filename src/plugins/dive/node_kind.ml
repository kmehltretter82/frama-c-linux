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

open Graph_types

let get_base = function
  | Scalar (vi,_) | Composite (vi) -> Some vi
  | Scattered _ | Alarm _ | File -> None

let is_precise = function
  | Scalar _ | Composite _ -> true
  | Scattered _ | Alarm _ | File -> false

let to_cil = function
  | Scalar (vi,offset) -> `Lval (Cil_types.Var vi, offset)
  | Composite (vi) -> `Lval (Cil_types.Var vi, Cil_types.NoOffset)
  | Scattered (lval) -> `Lval lval
  | Alarm (_stmt,exp) -> `Exp exp
  | File -> `None

let pretty fmt kind =
  match to_cil kind with
  | `Lval lval -> Cil_printer.pp_lval fmt lval
  | `Exp exp -> Cil_printer.pp_exp fmt exp
  | `None -> ()

