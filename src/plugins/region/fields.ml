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

open Ranges
open Cil_types
module Domain = Cil_datatype.Compinfo.Set

type field = fieldinfo range

type domain = Domain.t (* support for associating offsets to field name *)
let iter = Domain.iter
let union = Domain.union
let empty = Domain.empty
let singleton (fd : fieldinfo) = Domain.singleton fd.fcomp

(* minimal offset first, then minimal length, then largest struct *)
let compare (a : field) (b : field) =
  let cmp = a.offset - b.offset in
  if cmp <> 0 then cmp else
    let cmp = a.length - b.length in
    if cmp <> 0 then cmp else
      let sa = Cil.bitsSizeOf (TComp(a.data.fcomp,[])) in
      let sb = Cil.bitsSizeOf (TComp(b.data.fcomp,[])) in
      sb - sa

let find_all (fields: domain) (rg : _ range) =
  List.sort compare @@
  Domain.fold
    (fun c fds ->
       List.fold_left
         (fun fds fd ->
            let ofs,len = Cil.fieldBitsOffset fd in
            if rg.offset <= ofs && ofs + len <= rg.offset + rg.length then
              { offset = ofs ; length = len ; data = fd } :: fds
            else
              fds
         ) fds @@
       Option.value ~default:[] c.cfields
    ) fields []

let find fields rg =
  match find_all fields rg with
  | [] -> None
  | fr::_ -> Some fr

type slice = Bits of int | Field of fieldinfo

let pp_bits fmt n =
  if n <> 0 then Format.fprintf fmt "#%db" n

let pp_slice fmt = function
  | Bits n -> pp_bits fmt n
  | Field fd -> Format.fprintf fmt ".%s" fd.fname

let pad p q s =
  let n = q - p in
  if n > 0 then Bits n :: s else s

let last (rg : _ range) = rg.offset + rg.length

let span fields rg =
  match find_all fields rg with
  | [] -> [Bits rg.length]
  | fr :: frs ->
    pad rg.offset fr.offset @@
    Field fr.data ::
    let p = last fr in
    let q = last rg in
    match List.rev @@ List.filter (fun r -> p <= r.offset) frs with
    | [] -> pad p q []
    | lr :: _ ->
      pad p lr.offset @@ Field lr.data :: pad (last lr) q []

let pretty fields fmt rg =
  List.iter (pp_slice fmt) @@ span fields rg

let pslice fmt ~fields ~offset ~length =
  List.iter (pp_slice fmt) @@ span fields { offset ; length ; data = () }
