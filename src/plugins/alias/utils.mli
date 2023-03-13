(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C plug-in 'Alias' (alias).             *)
(*                                                                        *)
(*  Copyright (C) 2022-2023                                               *)
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
(*  for more details (enclosed in the file LICENSE)                       *)
(*                                                                        *)
(**************************************************************************)

(**  This is a collection of functions for other files of the plugin.
     /!\ Caution when re-using them /!\
*)

open Cil_types

open Cil_datatype

module VSet = Datatype.Int.Set
module VMap = Datatype.Int.Map

module LSet = Lval.Set
module LMap = Lval.Map

(** type of the return of the following function *)
type basic_lval =  BNone | BLval of lval | BAddrOf of lval | BIndex of basic_lval * exp

exception Double_lval of typ

(** finds, in an expression, the "basic" lval (eg a variable, a pointer or an array name). Raise Double_lval if two basic lval appear *)
val find_basic_lval : exp -> basic_lval

(** convert an index basic_lval into a lval *)
val convert_bindex : basic_lval -> lval

(** returns the list of all possible "prefix" of a lval lv1, i.e. each
    pair (lv,o) such as AddoffsetLval o lv = lv1 *)
val  decompose_lval : lval -> (lval*offset) list


(** [first_index a] returns a[0] *)
val first_index : lval -> lval

(** returns true if the index is OK (no needs to collapse) *)
val normalize_index : exp -> exp * bool
