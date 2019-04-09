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

open Cil_types

include Value_types.Callstack

type call_site = (Cil_types.kernel_function * Cil_types.kinstr)

let init kf = [(kf,Kglobal)]

let pop cs =
  match cs with
  | [] | (_,Kglobal) :: _ :: _ | [(_,Kstmt _)] -> assert false (* Invariant *)
  | [(_,Kglobal)] -> None
  | (kf,Kstmt stmt) :: t -> Some (kf,stmt,t)

let rec pop_downto top_kf = function
  | [] -> failwith "the callstack doesn't contain this function"
  | ((kf,_kinstr) :: tail) as cs ->
    if Kernel_function.equal kf top_kf
    then cs
    else pop_downto top_kf tail

let push (kf,stmt) cs =
  match cs with
  (* When the callstack is truncated, we ignore the first callsite *)
  | [] -> [(kf,Kglobal)]
  | cs -> (kf,Kstmt stmt) :: cs


