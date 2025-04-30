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

open Abstract_interp

(* To be completed with more involved strategies *)
type split_strategy =
  | NoSplit
  | SplitAuto
  | SplitEqList of Datatype.Integer.t list
  | FullSplit
[@@ deriving eq, ord]

include Datatype.Make (struct
    include Datatype.Serializable_undefined

    type t = split_strategy [@@ deriving eq, ord]
    let name = "Eva.Split_strategy"
    let reprs = [NoSplit]

    let hash = function
      | NoSplit -> 0
      | SplitAuto -> 1
      | FullSplit -> 2
      | SplitEqList l -> 3 + Hashtbl.hash (List.map Int.hash l)

    let pretty fmt = function
      | NoSplit -> Format.pp_print_string fmt "no split"
      | SplitAuto -> Format.pp_print_string fmt "auto split"
      | FullSplit -> Format.pp_print_string fmt "full split"
      | SplitEqList l ->
        Format.fprintf fmt "Split on \\result == %a"
          (Pretty_utils.pp_list ~sep:",@ " Datatype.Integer.pretty) l

    let copy = Datatype.identity
  end)

let of_string s =
  match s with
  | "" -> NoSplit
  | "full" -> FullSplit
  | "auto" -> SplitAuto
  | _ ->
    let r = Str.regexp ":" in
    let conv s =
      try Integer.of_string s
      with Invalid_argument _ ->
        raise (Self.Cannot_build ("unknown split strategy " ^ s))
    in
    SplitEqList (List.map conv (Str.split r s))

let to_string = function
  | NoSplit -> ""
  | SplitAuto -> "auto"
  | FullSplit -> "full"
  | SplitEqList l ->
    Format.asprintf "%t"
      (fun fmt ->
         Pretty_utils.pp_list ~sep:":" Datatype.Integer.pretty fmt l)
