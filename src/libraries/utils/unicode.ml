(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2025                                               *)
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

type printer = Format.formatter -> unit

let pretty utf8 ascii = fun fmt ->
  if Kernel.Unicode.get ()
  then Format.pp_print_string fmt utf8
  else Format.pp_print_string fmt ascii

let pp_in_set =    pretty Utf8_logic.inset "IN"
let pp_empty_set = pretty Utf8_logic.emptyset "EMPTY_SET"
let pp_union =     pretty Utf8_logic.union "U"
let pp_top =       pretty Utf8_logic.top "TOP"
let pp_bottom =    pretty Utf8_logic.bottom "BOTTOM"
