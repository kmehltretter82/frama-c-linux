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

(* minimal offset first, then maximal length, then largest struct *)
let compare (a : field) (b : field) =
  let cmp = a.offset - b.offset in
  if cmp <> 0 then cmp else
    let cmp = b.length - a.length in
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

let delta (a : _ range) (b : _ range) =
  let p = a.offset + a.length in
  let q = b.offset in
  if p < q then [Bits (q - p)] else []

let span fields rg =
  match find_all fields rg with
  | [] -> [Bits rg.length]
  | fr :: frs ->
    delta rg fr @ [Field fr.data] @
    match List.rev frs with
    | [] -> delta fr rg
    | lr :: _ -> delta fr lr @ [Field lr.data] @ delta lr rg

let pp_bits fmt n =
  if n <> 0 then Format.fprintf fmt "#%db" n

let pp_slice fmt = function
  | Bits n -> pp_bits fmt n
  | Field fd -> Format.fprintf fmt ".%s" fd.fname

let pretty fields fmt rg =
  List.iter (pp_slice fmt) @@ span fields rg

let pslice fmt ~fields ~offset ~length =
  List.iter (pp_slice fmt) @@ span fields { offset ; length ; data = () }
