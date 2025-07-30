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
  then Format.pp_print_as fmt 1 utf8
  else Format.pp_print_string fmt ascii

(* Set operations. *)

let pp_in_set =    pretty Utf8_logic.inset "IN"
let pp_empty_set = pretty Utf8_logic.emptyset "EMPTY_SET"
let pp_union =     pretty Utf8_logic.union "U"
let pp_top =       pretty Utf8_logic.top "TOP"
let pp_bottom =    pretty Utf8_logic.bottom "BOTTOM"

(* Relations. *)

let pp_le =  pretty Utf8_logic.le "<="
let pp_ge =  pretty Utf8_logic.ge ">="
let pp_eq =  pretty Utf8_logic.eq "=="
let pp_neq = pretty Utf8_logic.neq "!="

(* Logic operators. *)

let pp_not = pretty Utf8_logic.neg "!"
let pp_and = pretty Utf8_logic.conj "&&"
let pp_or =  pretty Utf8_logic.disj "||"
let pp_xor = pretty Utf8_logic.x_or "^^"

let pp_implies = pretty Utf8_logic.implies "==>"
let pp_iff =     pretty Utf8_logic.iff "<==>"

let pp_in_acsl = pretty Utf8_logic.inset "\\in"
let pp_forall = pretty Utf8_logic.forall "\\forall"
let pp_exists = pretty Utf8_logic.exists "\\exists"

(* Logic types. *)

let pp_boolean = pretty Utf8_logic.boolean "boolean"
let pp_integer = pretty Utf8_logic.integer "integer"
let pp_real =    pretty Utf8_logic.real "real"

(* Greek letters. *)

let pp_pi = pretty Utf8_logic.pi "\\pi"
let pp_lambda = pretty "λ" "\\lambda"
let pp_mu = pretty "µ" "\\mu"

(* Other symbols. *)

let pp_right_arrow = pretty "→" "->"
let pp_plus_minus = pretty "±" "+/-"
let pp_times = pretty "×" "x"
let pp_ellipsis = pretty "…" "..."

let pp_lceil = pretty "⌈" "ceil("
let pp_rceil = pretty "⌉" ")"
let pp_lfloor = pretty "⌊" "floor("
let pp_rfloor = pretty "⌋" ")"

let pp_ceil pp fmt elt = Format.fprintf fmt "%t%a%t" pp_lceil pp elt pp_rceil
let pp_floor pp fmt elt = Format.fprintf fmt "%t%a%t" pp_lfloor pp elt pp_rfloor
