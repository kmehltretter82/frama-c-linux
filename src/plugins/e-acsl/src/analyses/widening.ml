(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2022                                               *)
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
open Analyses_types
open Interval_utils

let interv_of_typ_containing_interv = function
  | Float _ | Rational | Real | Nan as x ->
    x
  | Ival i ->
    try
      let kind = ikind_of_ival i in
      interv_of_typ (TInt(kind, []))
    with Cil.Not_representable ->
      top_ival

let is_lower l1 l2 =
  match l1, l2 with
  | None, _ -> true
  | Some l1, Some l2 -> Integer.compare l1 l2 <= 0
  | Some _, None -> false

let is_higher u1 u2 =
    match u1, u2 with
  | None, _ -> true
  | Some u1, Some u2 -> Integer.compare u1 u2 >= 0
  | Some _, None -> false

let widen i1 i2 =
  match i1, i2 with
  | Ival i1, _ when Ival.is_bottom i1 -> i2
  | Ival i1, Ival i2 ->
    (try
       let kind = ikind_of_ival (Ival.join i1 i2) in
       let i = ival_of_ikind kind in
       let l1,u1 = Ival.min_and_max i1 in
       let l2,u2 = Ival.min_and_max i2 in
       let lmask = if is_lower l1 l2 then l1 else None in
       let umask = if is_higher u1 u2  then u1 else None in
       Ival (Ival.meet i (Ival.inject_range lmask umask))
     with Cil.Not_representable -> top_ival)
  | Float _, Float _ | Rational, Rational | Real, Real | Nan, Nan ->
    join i1 i2
  | Ival _, _| Float _, _ | Rational, _ | Real, _ | Nan, _ -> assert false

let ext_profile =
  Cil_datatype.Logic_var.Map.map interv_of_typ_containing_interv
