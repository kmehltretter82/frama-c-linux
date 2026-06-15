(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Cil_types

let strip_shallow_cast t =
  match t.term_node with
  | TCast (_,_,t) -> t
  | _ -> t

let extract_integer t =
  match (strip_shallow_cast t).term_node with
  | TConst (Integer (z, _)) -> Some z
  | _ -> None
