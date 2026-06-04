(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

type attr = [ `Nullable | `Allocated | `Garbage | `Validread ]
type flags = A of int [@@ unboxed]

let flag = function
  | `Nullable  -> 0b0001
  | `Allocated -> 0b0010
  | `Garbage   -> 0b0100
  | `Validread  -> 0b1000

let empty = A 0
let add a (A w) = A (flag a lor w)
let mem a (A w) = flag a land w <> 0
let union (A x) (A y) = A (x lor y)
let subset (A x) (A y) = (x lor y) = y

let iter f w =
  List.iter
    (fun a -> if mem a w then f a)
    [ `Nullable ; `Allocated ; `Garbage ; `Validread ]

let pp_attr fmt = function
  | `Nullable  -> Format.pp_print_string fmt "nullable"
  | `Allocated -> Format.pp_print_string fmt "allocated"
  | `Garbage   -> Format.pp_print_string fmt "garbage"
  | `Validread  -> Format.pp_print_string fmt "validread"

let reversed = flag `Validread
(* flags that shall be merged with land instead of lor *)

let bottom = A reversed
let merge (A x) (A y) =
  let flip w = reversed lxor w in
  A (flip (flip x lor flip y))

let pretty fmt w =
  begin
    Format.fprintf fmt "@[<hov 2>" ;
    let sep = ref false in
    let next a =
      if !sep then Format.fprintf fmt ",@," else sep := true ;
      pp_attr fmt a in
    iter next w ;
    Format.fprintf fmt "@]" ;
  end

open Cil_types

let is_local v =
  not (v.vglob || v.vformal)

let is_initialized ~garbage v =
  v.vglob || v.vdefined ||
  (v.vformal && not garbage) ||
  (v.vtemp && not @@ Ast_types.is_struct_or_union v.vtype)

let is_const v =
  (v.vformal || v.vglob || v.vdefined) &&
  Ast_types.is_const v.vtype

let cvar ~garbage v =
  let flags = ref empty in
  let set f = flags := add f !flags in
  if is_local v then set `Allocated ;
  if is_const v then set `Validread ;
  if not @@ is_initialized ~garbage v then set `Garbage ;
  !flags
